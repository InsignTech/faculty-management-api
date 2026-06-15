-- ============================================================
-- Fix for: Unknown column 'is_leave_type' in 'field list'
-- Root cause: sp_approve_leave references 'is_leave_type' but
--             the attendance_daily table has NO such column.
--             The correct columns are: is_leave (tinyint),
--             leave_shift_type (enum)
--
-- Run this entire script as root in MySQL Workbench or CLI:
--   mysql -u root -p staffdesk < fix_sp_approve_leave.sql
-- ============================================================

USE staffdesk;

DROP PROCEDURE IF EXISTS sp_approve_leave;

DELIMITER $$

CREATE PROCEDURE sp_approve_leave(
    IN p_leave_request_id INT,
    IN p_approved_by      INT,
    IN p_action           VARCHAR(20),
    IN p_remarks          TEXT,
    IN p_substitute_id    INT
)
proc: BEGIN
    DECLARE v_emp_id        INT;
    DECLARE v_start_date    DATE;
    DECLARE v_end_date      DATE;
    DECLARE v_leave_type    VARCHAR(100);
    DECLARE v_leave_half    VARCHAR(20);
    DECLARE v_approver_1    INT;
    DECLARE v_approver_2    INT;
    DECLARE v_current_level INT DEFAULT 1;
    DECLARE v_status        VARCHAR(20);
    DECLARE v_current_date  DATE;

    -- Fetch leave request details
    SELECT
        lr.employee_id, lr.start_date, lr.end_date,
        lr.leave_type, lr.leave_half_type,
        lr.approver_1_id, lr.approver_2_id,
        lr.current_level, lr.status
    INTO
        v_emp_id, v_start_date, v_end_date,
        v_leave_type, v_leave_half,
        v_approver_1, v_approver_2,
        v_current_level, v_status
    FROM leave_requests lr
    WHERE lr.leave_request_id = p_leave_request_id
    FOR UPDATE;

    -- Guard: already actioned
    IF v_status NOT IN ('Pending') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Request is already actioned or does not exist';
    END IF;

    -- Update substitute if provided by approver
    IF p_substitute_id IS NOT NULL THEN
        UPDATE leave_requests SET substitute_employee_id = p_substitute_id
        WHERE leave_request_id = p_leave_request_id;
    END IF;

    -- Handle REJECTION at any level
    IF p_action = 'Rejected' THEN
        UPDATE leave_requests SET
            status             = 'Rejected',
            approved_by_id     = p_approved_by,
            approved_on        = NOW(),
            approver_1_remarks = IF(v_current_level = 1, p_remarks, approver_1_remarks),
            approver_2_remarks = IF(v_current_level = 2, p_remarks, approver_2_remarks)
        WHERE leave_request_id = p_leave_request_id;

        SELECT p_leave_request_id AS leave_request_id, 'Rejected' AS result_status, NULL AS next_level;
        LEAVE proc;
    END IF;

    -- Handle APPROVAL at Level 1
    IF p_action = 'Approved' AND v_current_level = 1 THEN
        IF v_approver_2 IS NOT NULL THEN
            -- Advance to Level 2 (no attendance update yet)
            UPDATE leave_requests SET
                current_level        = 2,
                approver_1_remarks   = p_remarks,
                approver_1_action_on = NOW()
            WHERE leave_request_id = p_leave_request_id;

            SELECT p_leave_request_id AS leave_request_id, 'Pending' AS result_status, 2 AS next_level;
            LEAVE proc;
        ELSE
            -- Single-level approval — mark Approved, then update attendance
            UPDATE leave_requests SET
                status               = 'Approved',
                approved_by_id       = p_approved_by,
                approved_on          = NOW(),
                approver_1_remarks   = p_remarks,
                approver_1_action_on = NOW()
            WHERE leave_request_id = p_leave_request_id;
        END IF;
    END IF;

    -- Handle APPROVAL at Level 2 (final)
    IF p_action = 'Approved' AND v_current_level = 2 THEN
        UPDATE leave_requests SET
            status               = 'Approved',
            approved_by_id       = p_approved_by,
            approved_on          = NOW(),
            approver_2_remarks   = p_remarks,
            approver_2_action_on = NOW()
        WHERE leave_request_id = p_leave_request_id;
    END IF;

    -- ── Phase 1: Conflict validation ────────────────────────────────────────
    SET v_current_date = v_start_date;
    validation_loop: WHILE v_current_date <= v_end_date DO
        SET @reg_shift   = NULL;
        SET @is_leave    = 0;
        SET @leave_shift = NULL;

        SELECT regularization_shift_type, is_leave, leave_shift_type
        INTO @reg_shift, @is_leave, @leave_shift
        FROM attendance_daily
        WHERE employee_id = v_emp_id AND date = v_current_date
        FOR UPDATE;

        IF @reg_shift IS NOT NULL THEN
            IF @reg_shift = 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: One or more days are already fully regularized/on-duty';
            END IF;
            IF @reg_shift = v_leave_half AND v_leave_half != 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: This half of the day is already regularized/on-duty';
            END IF;
            IF v_leave_half = 'FullDay' AND @reg_shift != 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: A part of this day is already regularized/on-duty.';
            END IF;
        END IF;

        IF @is_leave = 1 THEN
            IF @leave_shift = 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: One or more days already have an approved leave';
            END IF;
            IF @leave_shift = v_leave_half AND v_leave_half != 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: An approved leave already exists for this half-day';
            END IF;
            IF v_leave_half = 'FullDay' AND @leave_shift != 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: A part of this day already has an approved leave.';
            END IF;
        END IF;

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE;

    -- ── Phase 2: Deduct leave balance ──────────────────────────────────────
    SET @v_total_days = 0;
    SELECT total_days INTO @v_total_days
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
    VALUES (v_emp_id, v_leave_type, DATE_FORMAT(v_start_date, '%m-%Y'), 0, 0, @v_total_days)
    ON DUPLICATE KEY UPDATE
        leaves_taken = leaves_taken + @v_total_days;

    -- ── Phase 3: Update attendance_daily ───────────────────────────────────
    --   NOTE: 'is_leave_type' does NOT exist in attendance_daily.
    --         Using only valid columns: is_leave (tinyint), leave_shift_type (enum)
    SET v_current_date = v_start_date;
    date_loop: WHILE v_current_date <= v_end_date DO

        -- Skip weekends / holidays already marked
        SET @existing_status = NULL;
        SELECT status INTO @existing_status
        FROM attendance_daily
        WHERE employee_id = v_emp_id AND date = v_current_date
        LIMIT 1;

        IF @existing_status IN ('WeekEnd', 'Public Holiday', 'Exceptional Holiday') THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        -- Skip public holidays from holiday_master
        IF EXISTS (
            SELECT 1 FROM holiday_master
            WHERE v_current_date BETWEEN holiday_start_date AND holiday_end_date
              AND is_active = 1
              AND employee_id IN (v_emp_id, -1)
        ) THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        -- Read existing attendance for this date
        SET @first_in            = NULL;
        SET @last_out            = NULL;
        SET @worked_mins         = 0;
        SET @cur_shift           = NULL;
        SET @cur_status          = NULL;
        SET @reg_shift           = NULL;
        SET @od_shift            = NULL;
        SET @is_leave_existing   = 0;
        SET @leave_shift_existing = NULL;

        SELECT
            first_in_time, last_out_time, worked_mins,
            shift_type, status,
            regularization_shift_type, onduty_shift_type,
            is_leave, leave_shift_type
        INTO
            @first_in, @last_out, @worked_mins,
            @cur_shift, @cur_status,
            @reg_shift, @od_shift,
            @is_leave_existing, @leave_shift_existing
        FROM attendance_daily
        WHERE employee_id = v_emp_id AND date = v_current_date
        LIMIT 1;

        -- Determine coverage
        SET @v_first_half_covered = (
            (@cur_shift IN ('FirstHalf', 'FullDay')) OR
            (@reg_shift IN ('FirstHalf', 'FullDay')) OR
            (@od_shift  IN ('FirstHalf', 'FullDay')) OR
            (@is_leave_existing = 1 AND @leave_shift_existing IN ('FirstHalf', 'FullDay')) OR
            (v_leave_half IN ('FirstHalf', 'FullDay'))
        );

        SET @v_second_half_covered = (
            (@cur_shift IN ('SecondHalf', 'FullDay')) OR
            (@reg_shift IN ('SecondHalf', 'FullDay')) OR
            (@od_shift  IN ('SecondHalf', 'FullDay')) OR
            (@is_leave_existing = 1 AND @leave_shift_existing IN ('SecondHalf', 'FullDay')) OR
            (v_leave_half IN ('SecondHalf', 'FullDay'))
        );

        SET @final_deduct = IF(@v_first_half_covered AND @v_second_half_covered, 0.00, 0.50);
        IF NOT @v_first_half_covered AND NOT @v_second_half_covered THEN
            SET @final_deduct = 1.00;
        END IF;

        SET @final_shift = 'Absent';
        IF @v_first_half_covered AND @v_second_half_covered THEN
            SET @final_shift = 'FullDay';
        ELSEIF @v_first_half_covered THEN
            SET @final_shift = 'FirstHalf';
        ELSEIF @v_second_half_covered THEN
            SET @final_shift = 'SecondHalf';
        END IF;

        SET @final_status = IF(
            @final_shift = 'FullDay' OR @cur_shift = 'FullDay',
            'Present',
            'Leave'
        );

        -- Upsert attendance_daily — NO is_leave_type column
        INSERT INTO attendance_daily (
            employee_id, date,
            first_in_time, last_out_time, worked_mins,
            shift_type, status,
            is_late, late_minutes,
            is_early_leaving, early_minutes,
            overtime_minutes, deduction_days,
            is_worked_on_holiday,
            is_leave, leave_shift_type
        ) VALUES (
            v_emp_id, v_current_date,
            @first_in, @last_out, @worked_mins,
            @final_shift, @final_status,
            0, 0, 0, 0,
            0, @final_deduct, 0,
            1, v_leave_half
        )
        ON DUPLICATE KEY UPDATE
            shift_type       = @final_shift,
            status           = @final_status,
            deduction_days   = @final_deduct,
            is_leave         = 1,
            leave_shift_type = IF(
                v_leave_half = 'FullDay', 'FullDay',
                IF(@is_leave_existing = 1 AND @leave_shift_existing != v_leave_half,
                   'FullDay',
                   v_leave_half)
            );

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE date_loop;

    COMMIT;

    -- Final result
    SELECT
        p_leave_request_id   AS leave_request_id,
        v_emp_id             AS employee_id,
        v_start_date         AS start_date,
        v_end_date           AS end_date,
        v_leave_half         AS leave_half_type,
        'Approved'           AS result_status,
        NULL                 AS next_level,
        DATEDIFF(v_end_date, v_start_date) + 1 AS calendar_days,
        (SELECT total_days FROM leave_requests
         WHERE leave_request_id = p_leave_request_id) AS working_days_deducted;

END$$

DELIMITER ;

-- Verify it was created
SELECT ROUTINE_NAME, CREATED, LAST_ALTERED
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'staffdesk'
  AND ROUTINE_NAME = 'sp_approve_leave';
