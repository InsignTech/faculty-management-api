-- ============================================================
-- 2-Level Approval + Substitute Feature Migration
-- Run this on your MySQL staffdesk database
-- ============================================================

USE `staffdesk`;

-- ============================================================
-- 1. EMPLOYEE APPROVER CONFIG TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS `employee_approver_configs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `employee_id` INT NOT NULL,
    `request_type` ENUM('LEAVE', 'REGULARISATION', 'ONDUTY') NOT NULL,
    `approver_1_id` INT NOT NULL,
    `approver_2_id` INT NULL,
    UNIQUE KEY `idx_emp_req_type` (`employee_id`, `request_type`),
    CONSTRAINT `fk_eac_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_eac_approver1` FOREIGN KEY (`approver_1_id`) REFERENCES `employee` (`employee_id`),
    CONSTRAINT `fk_eac_approver2` FOREIGN KEY (`approver_2_id`) REFERENCES `employee` (`employee_id`)
);

-- ============================================================
-- 2. ALTER leave_requests — add 2-level approval + substitute columns
-- ============================================================
ALTER TABLE leave_requests
ADD COLUMN substitute_employee_id INT NULL,
ADD COLUMN approver_1_id INT NULL,
ADD COLUMN approver_2_id INT NULL,
ADD COLUMN current_level TINYINT NOT NULL DEFAULT 1,
ADD COLUMN approver_1_remarks TEXT NULL,
ADD COLUMN approver_1_action_on DATETIME NULL,
ADD COLUMN approver_2_remarks TEXT NULL,
ADD COLUMN approver_2_action_on DATETIME NULL;

-- Add foreign keys for leave_requests (ignore errors if already exist)
ALTER TABLE leave_requests
ADD CONSTRAINT fk_lr_substitute
    FOREIGN KEY (substitute_employee_id)
    REFERENCES employee(employee_id),
ADD CONSTRAINT fk_lr_approver1
    FOREIGN KEY (approver_1_id)
    REFERENCES employee(employee_id),
ADD CONSTRAINT fk_lr_approver2
    FOREIGN KEY (approver_2_id)
    REFERENCES employee(employee_id);
-- ============================================================
-- 3. ALTER attendance_regularization — same columns
-- ============================================================
ALTER TABLE attendance_regularization
ADD COLUMN substitute_employee_id INT NULL,
ADD COLUMN approver_1_id INT NULL,
ADD COLUMN approver_2_id INT NULL,
ADD COLUMN current_level TINYINT NOT NULL DEFAULT 1,
ADD COLUMN approver_1_remarks TEXT NULL,
ADD COLUMN approver_1_action_on DATETIME NULL,
ADD COLUMN approver_2_remarks TEXT NULL,
ADD COLUMN approver_2_action_on DATETIME NULL;

ALTER TABLE attendance_regularization
ADD CONSTRAINT fk_ar_substitute
    FOREIGN KEY (substitute_employee_id)
    REFERENCES employee(employee_id),
ADD CONSTRAINT fk_ar_approver1
    FOREIGN KEY (approver_1_id)
    REFERENCES employee(employee_id),
ADD CONSTRAINT fk_ar_approver2
    FOREIGN KEY (approver_2_id)
    REFERENCES employee(employee_id);

-- ============================================================
-- 4. STORED PROCEDURE: Get approver config for an employee
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_get_approver_config`;
DELIMITER //
CREATE PROCEDURE `sp_get_approver_config`(
    IN p_employee_id INT,
    IN p_request_type ENUM('LEAVE','REGULARISATION','ONDUTY')
)
BEGIN
    -- Returns configured approvers, or falls back to reporting_manager / principal
    DECLARE v_manager_id INT;
    DECLARE v_principal_id INT;

    SELECT reporting_manager_id INTO v_manager_id
    FROM employee WHERE employee_id = p_employee_id;

    SELECT e.employee_id INTO v_principal_id
    FROM employee e
    JOIN app_role r ON e.role_id = r.role_id
    WHERE r.role IN ('Principal','principal') AND e.active = 1
    LIMIT 1;

    SELECT
        COALESCE(eac.approver_1_id, v_manager_id, v_principal_id) AS approver_1_id,
        eac.approver_2_id,
        COALESCE(a1.employee_name, m.employee_name, p.employee_name) AS approver_1_name,
        a2.employee_name AS approver_2_name
    FROM (SELECT 1) dummy
    LEFT JOIN employee_approver_configs eac
        ON eac.employee_id = p_employee_id AND eac.request_type = p_request_type
    LEFT JOIN employee a1 ON a1.employee_id = eac.approver_1_id
    LEFT JOIN employee m  ON m.employee_id  = v_manager_id
    LEFT JOIN employee p  ON p.employee_id  = v_principal_id
    LEFT JOIN employee a2 ON a2.employee_id = eac.approver_2_id;
END //
DELIMITER ;

-- ============================================================
-- 5. STORED PROCEDURE: Save approver config for an employee
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_save_approver_config`;
DELIMITER //
CREATE PROCEDURE `sp_save_approver_config`(
    IN p_employee_id   INT,
    IN p_request_type  ENUM('LEAVE','REGULARISATION','ONDUTY'),
    IN p_approver_1_id INT,
    IN p_approver_2_id INT
)
BEGIN
    INSERT INTO employee_approver_configs (employee_id, request_type, approver_1_id, approver_2_id)
    VALUES (p_employee_id, p_request_type, p_approver_1_id, p_approver_2_id)
    ON DUPLICATE KEY UPDATE
        approver_1_id = p_approver_1_id,
        approver_2_id = p_approver_2_id;

    SELECT ROW_COUNT() AS affected_rows;
END //
DELIMITER ;

-- ============================================================
-- 6. STORED PROCEDURE: Check substitute availability
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_check_substitute_availability`;
DELIMITER //
CREATE PROCEDURE `sp_check_substitute_availability`(
    IN p_substitute_id INT,
    IN p_start_date    DATE,
    IN p_end_date      DATE
)
BEGIN
    -- Returns rows if substitute has conflicting approved/pending leave
    SELECT
        lr.leave_request_id,
        lr.start_date,
        lr.end_date,
        lr.leave_type,
        lr.status
    FROM leave_requests lr
    WHERE lr.employee_id = p_substitute_id
      AND lr.status IN ('Pending','Approved')
      AND lr.start_date <= p_end_date
      AND lr.end_date   >= p_start_date
    LIMIT 5;
END //
DELIMITER ;

-- ============================================================
-- 7. UPDATE sp_apply_leave — store approver_1_id, approver_2_id, substitute
-- ============================================================
DROP PROCEDURE IF EXISTS sp_apply_leave;
DELIMITER //

CREATE PROCEDURE sp_apply_leave(
    IN p_employee_id          INT,
    IN p_leave_type           VARCHAR(50),
    IN p_start_date           DATE,
    IN p_end_date             DATE,
    IN p_total_days           DECIMAL(5,2),
    IN p_reason               TEXT,
    IN p_attachment_path      VARCHAR(512),
    IN p_substitute_id        INT,
    IN p_approver_1_id        INT,
    IN p_approver_2_id        INT
)
BEGIN
    DECLARE v_principal_id INT;
    DECLARE v_manager_id   INT;
    DECLARE v_a1           INT;
    DECLARE v_a2           INT;

    /* Allow only current month and future dates */
    IF p_start_date < DATE_FORMAT(CURDATE(), '%Y-%m-01') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Leave can only be applied within the current month.';
    END IF;

    SELECT reporting_manager_id
    INTO v_manager_id
    FROM employee
    WHERE employee_id = p_employee_id;

    /* Adjust this query if your table is roles instead of app_role */
    SELECT e.employee_id
    INTO v_principal_id
    FROM employee e
    JOIN app_role r ON e.role_id = r.role_id
    WHERE r.role IN ('Principal','principal')
      AND e.active = 1
    LIMIT 1;

    SET v_a1 = COALESCE(p_approver_1_id, v_manager_id, v_principal_id);
    SET v_a2 = p_approver_2_id;

    IF p_approver_1_id IS NULL THEN

        SELECT
            COALESCE(
                eac.approver_1_id,
                v_manager_id,
                v_principal_id
            ),
            eac.approver_2_id
        INTO v_a1, v_a2
        FROM (SELECT 1) d
        LEFT JOIN employee_approver_configs eac
            ON eac.employee_id = p_employee_id
           AND eac.request_type = 'LEAVE';

        SET v_a1 = COALESCE(
            v_a1,
            v_manager_id,
            v_principal_id
        );

    END IF;

    INSERT INTO leave_requests (
        employee_id,
        leave_type,
        start_date,
        end_date,
        total_days,
        reason,
        attachment_path,
        status,
        applied_on,
        substitute_employee_id,
        approver_1_id,
        approver_2_id,
        current_level
    )
    VALUES (
        p_employee_id,
        p_leave_type,
        p_start_date,
        p_end_date,
        p_total_days,
        p_reason,
        p_attachment_path,
        'Pending',
        NOW(),
        p_substitute_id,
        v_a1,
        v_a2,
        1
    );

    SELECT LAST_INSERT_ID() AS leave_request_id;

END //

DELIMITER ;

-- ============================================================
-- 8. UPDATE sp_approve_leave — 2-level logic + per-level remarks
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_approve_leave`;
DELIMITER //
CREATE PROCEDURE `sp_approve_leave`(
    IN p_leave_request_id  INT,
    IN p_approved_by       INT,
    IN p_action            ENUM('Approved','Rejected'),
    IN p_remarks           TEXT,
    IN p_substitute_id     INT  -- approver can override substitute, NULL = no change
)
proc: BEGIN

    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_leave_type     VARCHAR(50);
    DECLARE v_leave_half     VARCHAR(20);
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_current_level  TINYINT;
    DECLARE v_approver_1_id  INT;
    DECLARE v_approver_2_id  INT;
    DECLARE v_current_date   DATE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Load request
    SELECT
        employee_id, start_date, end_date, leave_type,
        COALESCE(leave_half_type, 'FullDay'),
        status, current_level, approver_1_id, approver_2_id
    INTO
        v_emp_id, v_start_date, v_end_date, v_leave_type,
        v_leave_half, v_current_status, v_current_level,
        v_approver_1_id, v_approver_2_id
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leave request not found';
    END IF;

    IF v_current_status != 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only Pending requests can be actioned';
    END IF;

    IF p_action = 'Rejected' AND (p_remarks IS NULL OR TRIM(p_remarks) = '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Remarks are required when rejecting';
    END IF;

    -- Validate the actor is the correct level approver
    IF v_current_level = 1 AND p_approved_by != v_approver_1_id THEN
        -- Allow admin / principal to override
        IF NOT EXISTS (
            SELECT 1 FROM employee e
            JOIN app_role r ON e.role_id = r.role_id
            WHERE e.employee_id = p_approved_by
              AND r.role IN ('Admin','admin','Principal','principal','super_admin','HOD')
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are not the designated Level 1 approver for this request';
        END IF;
    END IF;

    IF v_current_level = 2 AND p_approved_by != v_approver_2_id THEN
        IF NOT EXISTS (
            SELECT 1 FROM employee e
            JOIN app_role r ON e.role_id = r.role_id
            WHERE e.employee_id = p_approved_by
              AND r.role IN ('Admin','admin','Principal','principal','super_admin','HOD')
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are not the designated Level 2 approver for this request';
        END IF;
    END IF;

    -- Update substitute if provided by approver
    IF p_substitute_id IS NOT NULL THEN
        UPDATE leave_requests SET substitute_employee_id = p_substitute_id
        WHERE leave_request_id = p_leave_request_id;
    END IF;

    -- Handle REJECTION (any level)
    IF p_action = 'Rejected' THEN
        IF v_current_level = 1 THEN
            UPDATE leave_requests SET
                status = 'Rejected',
                approver_1_remarks = p_remarks,
                approver_1_action_on = NOW()
            WHERE leave_request_id = p_leave_request_id;
        ELSE
            UPDATE leave_requests SET
                status = 'Rejected',
                approver_2_remarks = p_remarks,
                approver_2_action_on = NOW()
            WHERE leave_request_id = p_leave_request_id;
        END IF;

        COMMIT;
        SELECT p_leave_request_id AS leave_request_id, 'Rejected' AS result_status, NULL AS next_level;
        LEAVE proc;
    END IF;

    -- Handle APPROVAL at Level 1
    IF p_action = 'Approved' AND v_current_level = 1 THEN
        IF v_approver_2_id IS NOT NULL THEN
            -- Advance to Level 2
            UPDATE leave_requests SET
                approver_1_remarks = p_remarks,
                approver_1_action_on = NOW(),
                current_level = 2
            WHERE leave_request_id = p_leave_request_id;

            COMMIT;
            SELECT p_leave_request_id AS leave_request_id, 'Pending' AS result_status, 2 AS next_level;
            LEAVE proc;
        ELSE
            -- No level 2 — final approval
            UPDATE leave_requests SET
                status = 'Approved',
                approved_by_id = p_approved_by,
                approved_on = NOW(),
                approver_1_remarks = p_remarks,
                approver_1_action_on = NOW()
            WHERE leave_request_id = p_leave_request_id;
        END IF;
    END IF;

    -- Handle APPROVAL at Level 2 (final)
    IF p_action = 'Approved' AND v_current_level = 2 THEN
        UPDATE leave_requests SET
            status = 'Approved',
            approved_by_id = p_approved_by,
            approved_on = NOW(),
            approver_2_remarks = p_remarks,
            approver_2_action_on = NOW()
        WHERE leave_request_id = p_leave_request_id;
    END IF;

    -- ── Phase 1: Conflict validation ───────────────────────────────────────
    SET v_current_date = v_start_date;
    validation_loop: WHILE v_current_date <= v_end_date DO
        SET @reg_shift = NULL;
        SET @is_leave = 0;
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
    SELECT total_days INTO @v_total_days FROM leave_requests WHERE leave_request_id = p_leave_request_id;

    INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
    VALUES (v_emp_id, v_leave_type, DATE_FORMAT(NOW(), '%m-%Y'), 0, 0, @v_total_days)
    ON DUPLICATE KEY UPDATE
        leaves_taken = leaves_taken + @v_total_days;

    -- ── Phase 3: Update attendance_daily ───────────────────────────────────
    SET v_current_date = v_start_date;
    date_loop: WHILE v_current_date <= v_end_date DO
        SET @existing_status = NULL;
        SELECT status INTO @existing_status FROM attendance_daily
        WHERE employee_id = v_emp_id AND date = v_current_date LIMIT 1;

        IF @existing_status IN ('WeekEnd','Public Holiday','Exceptional Holiday') THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        IF EXISTS (
            SELECT 1 FROM holiday_master
            WHERE v_current_date BETWEEN holiday_start_date AND holiday_end_date
              AND is_active = 1 AND employee_id IN (v_emp_id, -1)
        ) THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        SET @first_in = NULL; SET @last_out = NULL; SET @worked_mins = 0;
        SET @cur_shift = NULL; SET @cur_status = NULL;
        SET @reg_shift = NULL; SET @od_shift = NULL;
        SET @is_leave_existing = 0; SET @leave_shift_existing = NULL;

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

        SET @v_first_half_covered = (
            (@cur_shift IN ('FirstHalf','FullDay')) OR
            (@reg_shift IN ('FirstHalf','FullDay')) OR
            (@od_shift IN ('FirstHalf','FullDay')) OR
            (@is_leave_existing = 1 AND @leave_shift_existing IN ('FirstHalf','FullDay')) OR
            (v_leave_half IN ('FirstHalf','FullDay'))
        );

        SET @v_second_half_covered = (
            (@cur_shift IN ('SecondHalf','FullDay')) OR
            (@reg_shift IN ('SecondHalf','FullDay')) OR
            (@od_shift IN ('SecondHalf','FullDay')) OR
            (@is_leave_existing = 1 AND @leave_shift_existing IN ('SecondHalf','FullDay')) OR
            (v_leave_half IN ('SecondHalf','FullDay'))
        );

        SET @final_deduct = IF(@v_first_half_covered AND @v_second_half_covered, 0.00, 0.50);
        IF NOT @v_first_half_covered AND NOT @v_second_half_covered THEN SET @final_deduct = 1.00; END IF;

        SET @final_shift = 'Absent';
        IF @v_first_half_covered AND @v_second_half_covered THEN SET @final_shift = 'FullDay';
        ELSEIF @v_first_half_covered THEN SET @final_shift = 'FirstHalf';
        ELSEIF @v_second_half_covered THEN SET @final_shift = 'SecondHalf';
        END IF;

        SET @final_status = IF(@final_shift = 'FullDay' OR @cur_shift = 'FullDay', 'Present', 'Leave');

        INSERT INTO attendance_daily (
            employee_id, date, first_in_time, last_out_time, worked_mins,
            shift_type, status, is_late, late_minutes, is_early_leaving, early_minutes,
            overtime_minutes, deduction_days, is_worked_on_holiday,
            is_leave, is_leave_type, leave_shift_type
        ) VALUES (
            v_emp_id, v_current_date, @first_in, @last_out, @worked_mins,
            @final_shift, @final_status, 0, 0, 0, 0, 0,
            @final_deduct, 0, 1, v_leave_type, v_leave_half
        )
        ON DUPLICATE KEY UPDATE
            shift_type      = @final_shift,
            status          = @final_status,
            deduction_days  = @final_deduct,
            is_leave        = 1,
            is_leave_type   = v_leave_type,
            leave_shift_type = IF(v_leave_half = 'FullDay', 'FullDay',
                                IF(@is_leave_existing = 1 AND @leave_shift_existing != v_leave_half, 'FullDay', v_leave_half));

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE date_loop;

    COMMIT;

    SELECT
        p_leave_request_id AS leave_request_id,
        v_emp_id           AS employee_id,
        v_start_date       AS start_date,
        v_end_date         AS end_date,
        v_leave_half       AS leave_half_type,
        'Approved'         AS result_status,
        NULL               AS next_level,
        DATEDIFF(v_end_date, v_start_date) + 1 AS calendar_days,
        (SELECT total_days FROM leave_requests WHERE leave_request_id = p_leave_request_id) AS working_days_deducted;

END //
DELIMITER ;
