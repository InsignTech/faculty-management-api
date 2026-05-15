

DELIMITER //

-- 1. Update Get Attendance History
DROP PROCEDURE IF EXISTS `sp_get_employee_attendance` //
CREATE PROCEDURE `sp_get_employee_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        ad.*,
        (SELECT GROUP_CONCAT(CONCAT(lr.leave_type, ' (', lr.leave_half_type, ')') SEPARATOR ', ')
         FROM leave_requests lr
         WHERE lr.employee_id = ad.employee_id 
           AND lr.status = 'Approved' 
           AND ad.date BETWEEN lr.start_date AND lr.end_date) as leave_details
    FROM attendance_daily ad
    WHERE ad.employee_id = p_employee_id 
      AND MONTH(ad.date) = p_month 
      AND YEAR(ad.date) = p_year
    ORDER BY ad.date DESC;
END //

-- 2. Update Attendance Summary
DROP PROCEDURE IF EXISTS `sp_get_attendance_summary` //
CREATE PROCEDURE `sp_get_attendance_summary`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        COUNT(DISTINCT CASE WHEN status = 'Present' THEN date END) AS total_days_present,
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_count,
        SUM(CASE WHEN is_early_leaving = 1 THEN 1 ELSE 0 END) AS early_leaving_count,
        SUM(CASE WHEN regularization_shift_type IS NOT NULL OR onduty_shift_type IS NOT NULL THEN 1 ELSE 0 END) AS regularized_count,
        SUM(deduction_days) AS total_deductions
    FROM attendance_daily
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year;
END //

-- 3. Update sp_cancel_leave
DROP PROCEDURE IF EXISTS `sp_cancel_leave` //
CREATE PROCEDURE `sp_cancel_leave`(
    IN p_leave_request_id INT,
    IN p_cancelled_by      INT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_leave_type VARCHAR(50);
    DECLARE v_total_days DECIMAL(10,2);
    DECLARE v_status VARCHAR(20);
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;

    SELECT employee_id, leave_type, total_days, status, start_date, end_date
    INTO v_emp_id, v_leave_type, v_total_days, v_status, v_start_date, v_end_date
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    UPDATE leave_requests
    SET status = 'Cancelled',
        approved_by_id = p_cancelled_by,
        approved_on = NOW()
    WHERE leave_request_id = p_leave_request_id;

    IF v_status = 'Approved' THEN
        UPDATE employee_leaves
        SET leaves_taken = leaves_taken - v_total_days
        WHERE emp_id = v_emp_id 
          AND leave_type = v_leave_type 
          AND month_year = DATE_FORMAT(NOW(), '%m-%Y');
        
        UPDATE attendance_daily
        SET is_leave = 0,
            is_leave_type = NULL,
            leave_shift_type = NULL,
            status = CASE 
                WHEN regularization_shift_type IS NOT NULL OR onduty_shift_type IS NOT NULL OR (shift_type IS NOT NULL AND shift_type != 'Absent') THEN 'Present'
                ELSE 'Absent'
            END
        WHERE employee_id = v_emp_id 
          AND date BETWEEN v_start_date AND v_end_date
          AND is_leave = 1;
    END IF;

    SELECT p_leave_request_id AS leave_request_id, 'Cancelled' AS status;
END //

-- 4. Update sp_approve_leave (Refactored for 3-way shift overlap)
DROP PROCEDURE IF EXISTS `sp_approve_leave` //
CREATE PROCEDURE `sp_approve_leave`(
    IN p_leave_request_id INT,
    IN p_approved_by      INT,
    IN p_action           ENUM('Approved','Rejected'),
    IN p_rejection_reason TEXT
)
proc: BEGIN
    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_leave_type     VARCHAR(50);
    DECLARE v_leave_half     VARCHAR(20);
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_current_date   DATE;

    SELECT employee_id, start_date, end_date, leave_type, COALESCE(leave_half_type, 'FullDay'), status
    INTO v_emp_id, v_start_date, v_end_date, v_leave_type, v_leave_half, v_current_status
    FROM leave_requests WHERE leave_request_id = p_leave_request_id;

    IF v_current_status IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leave request not found'; END IF;
    IF v_current_status != 'Pending' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only Pending requests can be processed'; END IF;

    IF p_action = 'Rejected' THEN
        UPDATE leave_requests SET status = 'Rejected', approved_by_id = p_approved_by, approved_on = NOW(), rejection_reason = p_rejection_reason
        WHERE leave_request_id = p_leave_request_id;
        SELECT p_leave_request_id AS leave_request_id, 'Rejected' AS status;
        LEAVE proc;
    END IF;

    -- Phase 1: Validation
    SET v_current_date = v_start_date;
    validation_loop: WHILE v_current_date <= v_end_date DO
        SET @l_shift = NULL; SET @r_shift = NULL; SET @o_shift = NULL;
        SELECT leave_shift_type, regularization_shift_type, onduty_shift_type 
        INTO @l_shift, @r_shift, @o_shift
        FROM attendance_daily WHERE employee_id = v_emp_id AND date = v_current_date FOR UPDATE;

        SET @existing_shift = COALESCE(@l_shift, @r_shift, @o_shift);
        IF @existing_shift IS NOT NULL THEN
            IF @existing_shift = 'FullDay' OR v_leave_half = 'FullDay' OR @existing_shift = v_leave_half THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: Shift already covered by Leave, Regularization or On-Duty';
            END IF;
        END IF;
        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE;

    -- Phase 2: Balance
    SET @v_total_days = 0;
    SELECT total_days INTO @v_total_days FROM leave_requests WHERE leave_request_id = p_leave_request_id;
    INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
    VALUES (v_emp_id, v_leave_type, DATE_FORMAT(NOW(), '%m-%Y'), 0, 0, @v_total_days)
    ON DUPLICATE KEY UPDATE leaves_taken = leaves_taken + @v_total_days;

    -- Phase 3: Attendance Update
    UPDATE leave_requests SET status = 'Approved', approved_by_id = p_approved_by, approved_on = NOW()
    WHERE leave_request_id = p_leave_request_id;

    SET v_current_date = v_start_date;
    date_loop: WHILE v_current_date <= v_end_date DO
        -- Skip weekends/holidays (simplified for this refactor, usually we check holiday_master)
        SET @is_holiday = EXISTS(SELECT 1 FROM holiday_master WHERE v_current_date BETWEEN holiday_start_date AND holiday_end_date AND is_active=1 AND employee_id IN (v_emp_id, -1));
        IF @is_holiday THEN SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY); ITERATE date_loop; END IF;

        SET @cur_shift = NULL;
        SELECT shift_type INTO @cur_shift FROM attendance_daily WHERE employee_id = v_emp_id AND date = v_current_date;

        -- Smart merge logic
        SET @final_status = 'Leave';
        SET @final_shift = v_leave_half;
        
        -- If other half is covered by physical work, regularization, or on-duty -> Present
        SET @other_covered = EXISTS(
            SELECT 1 FROM attendance_daily 
            WHERE employee_id = v_emp_id AND date = v_current_date 
            AND (
                (v_leave_half = 'FirstHalf' AND (shift_type IN ('SecondHalf','FullDay') OR regularization_shift_type IN ('SecondHalf','FullDay') OR onduty_shift_type IN ('SecondHalf','FullDay'))) OR
                (v_leave_half = 'SecondHalf' AND (shift_type IN ('FirstHalf','FullDay') OR regularization_shift_type IN ('FirstHalf','FullDay') OR onduty_shift_type IN ('FirstHalf','FullDay')))
            )
        );

        IF @other_covered OR @cur_shift = 'FullDay' THEN SET @final_status = 'Present'; END IF;

        INSERT INTO attendance_daily (employee_id, date, status, is_leave, is_leave_type, leave_shift_type, deduction_days)
        VALUES (v_emp_id, v_current_date, @final_status, 1, v_leave_type, v_leave_half, 0.00)
        ON DUPLICATE KEY UPDATE 
            status = @final_status, is_leave = 1, is_leave_type = v_leave_type, leave_shift_type = v_leave_half,
            deduction_days = IF(@final_status = 'Present', 0.00, deduction_days);

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE;

    SELECT p_leave_request_id AS leave_request_id, v_emp_id AS employee_id, 'Approved' AS status;
END //

DELIMITER ;
