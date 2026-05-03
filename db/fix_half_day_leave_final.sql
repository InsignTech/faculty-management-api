USE `staffdesk`;

-- ─── STEP 1: Fix existing records with total_days = 0 ───────────────────────
-- These were created before the safety-net was in place.
-- Single-day requests with 0 days = half-day was submitted with old SP
-- (which cast 'FirstHalf' string → DECIMAL 0.00)

-- Fix single-day requests: they are half-days (0.5)
UPDATE leave_requests
SET total_days = 0.5
WHERE total_days = 0 AND start_date = end_date;

-- Fix multi-day full-day requests: recalculate from date range
UPDATE leave_requests
SET total_days = DATEDIFF(end_date, start_date) + 1
WHERE total_days = 0 AND start_date != end_date;

-- ─── STEP 2: Ensure schema is ready for half-day tracking ──────────────────
ALTER TABLE `leave_requests` MODIFY COLUMN `total_days` DECIMAL(5,2) NOT NULL;

-- Add leave_half_type column if it doesn't exist
SET @dbname = DATABASE();
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'leave_requests' AND COLUMN_NAME = 'leave_half_type') > 0,
  'SELECT ''Column already exists''',
  'ALTER TABLE `leave_requests` ADD COLUMN `leave_half_type` ENUM(''FullDay'', ''FirstHalf'', ''SecondHalf'') DEFAULT ''FullDay'' AFTER `end_date`'
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ─── STEP 3: Replace sp_apply_leave with correct version ───────────────────
-- Uses holiday_master (not holidays) and correctly calculates 0.5 for half-days
DROP PROCEDURE IF EXISTS `sp_apply_leave`;
DELIMITER //
CREATE PROCEDURE `sp_apply_leave`(
    IN p_employee_id  INT,
    IN p_leave_type   VARCHAR(50),
    IN p_start_date   DATE,
    IN p_end_date     DATE,
    IN p_half_type    VARCHAR(20),  -- 'FullDay', 'FirstHalf', 'SecondHalf'
    IN p_reason       TEXT,
    IN p_attachment   VARCHAR(512)
)
BEGIN
    DECLARE v_total_days DECIMAL(5,2) DEFAULT 0;
    DECLARE v_current_date DATE;
    DECLARE v_skip TINYINT DEFAULT 0;

    -- Validate date range
    IF p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Start date cannot be after end date';
    END IF;

    -- Half day must be a single day
    IF p_half_type != 'FullDay' AND p_start_date != p_end_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Half day leave must be on a single date';
    END IF;

    -- Loop through each day, exclude Sundays and holidays from holiday_master
    SET v_current_date = p_start_date;
    WHILE v_current_date <= p_end_date DO
        SET v_skip = 0;

        -- Skip Sundays
        IF DAYNAME(v_current_date) = 'Sunday' THEN
            SET v_skip = 1;
        END IF;

        -- Skip holidays from holiday_master
        -- employee_id = -1 means general holiday for all employees
        IF v_skip = 0 AND EXISTS (
            SELECT 1 FROM holiday_master
            WHERE (v_current_date BETWEEN holiday_start_date AND holiday_end_date)
              AND is_active = 1
              AND (employee_id = -1 OR employee_id = p_employee_id)
              AND holiday_type != 'WeekEnd'
        ) THEN
            SET v_skip = 1;
        END IF;

        IF v_skip = 0 THEN
            IF p_half_type = 'FullDay' THEN
                SET v_total_days = v_total_days + 1;
            ELSE
                -- FirstHalf or SecondHalf = 0.5 days
                SET v_total_days = v_total_days + 0.5;
            END IF;
        END IF;

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE;

    -- Insert the leave request
    INSERT INTO leave_requests (
        employee_id, leave_type, start_date, end_date, leave_half_type,
        total_days, reason, attachment_path, status, applied_on
    ) VALUES (
        p_employee_id, p_leave_type, p_start_date, p_end_date, p_half_type,
        v_total_days, p_reason, p_attachment, 'Pending', NOW()
    );

    -- Return the result to the backend
    SELECT LAST_INSERT_ID() AS leave_request_id, v_total_days AS total_days, 'Pending' AS status;
END //
DELIMITER ;

SELECT 'Fix applied successfully. Verify results:' AS status;

-- Verification query: check current leave_requests data
SELECT leave_request_id, employee_id, leave_type, start_date, end_date,
       IFNULL(leave_half_type, 'N/A') AS leave_half_type, total_days, status
FROM leave_requests
ORDER BY applied_on DESC
LIMIT 10;
