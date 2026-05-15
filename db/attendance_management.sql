-- Attendance Management System: Tables and Processing Logic
USE `staffdesk`;

-- =============================================
-- 1. TABLES
-- =============================================

-- Raw logs from external application
CREATE TABLE IF NOT EXISTS `attendance_detail_log` (
    `log_id` INT NOT NULL AUTO_INCREMENT,
    `employee_id` INT NOT NULL,
    `date` DATE NOT NULL,
    `time` TIME NOT NULL,
    `created_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`log_id`)
);

-- Processed attendance summary
CREATE TABLE IF NOT EXISTS `attendance` (
    `attendance_id` INT NOT NULL AUTO_INCREMENT,
    `employee_id` INT NOT NULL,
    `date` DATE NOT NULL,
    `status` ENUM('Absent', 'Present') NOT NULL,
    `punch_type` ENUM('Onduty', 'Manual', 'Biometric') NOT NULL,
    `type` ENUM('PunchIn', 'PunchOut') NOT NULL,
    `shift_type` ENUM('First Half', 'Second Half', 'Full Day') NOT NULL,
    `punch_time` TIME NOT NULL,
    `created_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`attendance_id`),
    UNIQUE KEY `idx_emp_date_type` (`employee_id`, `date`, `type`),
    CONSTRAINT `fk_attendance_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
);

-- Attendance adjustments (Regularization / On-Duty)
CREATE TABLE IF NOT EXISTS `attendance_regularization` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `employee_id` INT NOT NULL,
    `request_type` ENUM('Regularization', 'OnDuty') NOT NULL,
    `requested_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `date` DATE NOT NULL,
    `requested_in_time` TIME NULL,
    `requested_out_time` TIME NULL,
    `regularization_shift_type` ENUM('FullDay', 'FirstHalf', 'SecondHalf') DEFAULT 'FullDay',
    `reason` TEXT,
    `status` ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Pending',
    `approved_by` INT NULL,
    `approved_on` DATETIME NULL,
    `attachment_path` VARCHAR(512) NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_regularization_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
);

-- =============================================
-- 2. STORED PROCEDURES
-- =============================================

DELIMITER //

-- Process Raw Logs into Attendance Table (College Policy Version)
DROP PROCEDURE IF EXISTS `sp_process_attendance_logs` //
CREATE PROCEDURE `sp_process_attendance_logs`(
    IN p_date DATE
)
BEGIN
    DECLARE v_grace_in TIME;
    DECLARE v_early_out TIME;
    DECLARE v_deduction_amount DECIMAL(3,2);
    
    -- Load settings
    SELECT setting_value INTO v_grace_in FROM attendance_settings WHERE setting_key = 'grace_in_time';
    SELECT setting_value INTO v_early_out FROM attendance_settings WHERE setting_key = 'early_out_threshold';
    SELECT CAST(setting_value AS DECIMAL(3,2)) INTO v_deduction_amount FROM attendance_settings WHERE setting_key = 'deduction_amount';

    -- 1. Process Punch-Ins
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_late, deduction_days)
    SELECT 
        adl.employee_id, 
        adl.date, 
        'Present', 
        'Biometric', 
        'PunchIn', 
        'Full Day', 
        MIN(adl.time),
        IF(MIN(adl.time) > v_grace_in, 1, 0),
        IF(MIN(adl.time) > v_grace_in, v_deduction_amount, 0.00)
    FROM attendance_detail_log adl
    INNER JOIN employee e ON adl.employee_id = e.employee_id
    WHERE adl.date = p_date AND e.active = 1
    GROUP BY adl.employee_id, adl.date
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_late = VALUES(is_late),
        deduction_days = VALUES(deduction_days),
        status = 'Present';

    -- 2. Process Punch-Outs
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_early_leaving, deduction_days)
    SELECT 
        adl.employee_id, 
        adl.date, 
        'Present', 
        'Biometric', 
        'PunchOut', 
        'Full Day', 
        MAX(adl.time),
        IF(MAX(adl.time) < v_early_out, 1, 0),
        IF(MAX(adl.time) < v_early_out, v_deduction_amount, 0.00)
    FROM attendance_detail_log adl
    INNER JOIN employee e ON adl.employee_id = e.employee_id
    WHERE adl.date = p_date AND e.active = 1
    GROUP BY adl.employee_id, adl.date
    HAVING COUNT(*) > 1
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_early_leaving = VALUES(is_early_leaving),
        deduction_days = GREATEST(deduction_days, VALUES(deduction_days)),
        status = 'Present';
        
    SELECT ROW_COUNT() AS processed_rows;
END //

-- Generic Adjustment Approval Logic
DROP PROCEDURE IF EXISTS `sp_handle_adjustment_approval` //
CREATE PROCEDURE `sp_handle_adjustment_approval`(
    IN p_adjustment_id INT,
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_date DATE;
    DECLARE v_type VARCHAR(20);
    DECLARE v_reg_shift VARCHAR(20);
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_approved_count INT;
    DECLARE v_limit INT DEFAULT 3;
    
    -- 1. Get adjustment details
    SELECT employee_id, date, request_type, regularization_shift_type 
    INTO v_emp_id, v_date, v_type, v_reg_shift
    FROM attendance_regularization 
    WHERE id = p_adjustment_id;
    
    SET v_month = MONTH(v_date);
    SET v_year = YEAR(v_date);
    
    -- 2. Update status to Approved
    UPDATE attendance_regularization 
    SET status = 'Approved', 
        approved_by = p_approver_id, 
        approved_on = NOW(),
        reason = CONCAT(COALESCE(reason, ''), ' | Final Approval: ', p_remarks)
    WHERE id = p_adjustment_id;
    
    -- 3. Apply changes to attendance_daily table based on type
    IF v_type = 'Regularization' THEN
        -- Count previous approved regularizations this month
        SELECT COUNT(*) INTO v_approved_count 
        FROM attendance_regularization 
        WHERE employee_id = v_emp_id 
          AND MONTH(date) = v_month 
          AND YEAR(date) = v_year 
          AND status = 'Approved'
          AND request_type = 'Regularization'
          AND id != p_adjustment_id;

        -- Load limit from settings
        SELECT CAST(setting_value AS UNSIGNED) INTO v_limit FROM attendance_settings WHERE setting_key = 'regularization_limit';
        SET v_limit = COALESCE(v_limit, 3);
          
        -- Read existing attendance for merge logic
        SET @cur_shift = NULL;
        SET @cur_leave = NULL;
        SET @cur_onduty = NULL;
        SET @is_leave = 0;

        SELECT shift_type, leave_shift_type, onduty_shift_type, is_leave
        INTO @cur_shift, @cur_leave, @cur_onduty, @is_leave
        FROM attendance_daily
        WHERE employee_id = v_emp_id AND date = v_date
        LIMIT 1;

        -- Merge logic: If (New Reg + Existing Punches/Leaves/OnDuty) = Full Day
        SET @final_deduct = 0.50;
        IF v_reg_shift = 'FullDay' THEN
            SET @final_deduct = 0.00;
        ELSEIF v_reg_shift = 'FirstHalf' THEN
            IF @cur_shift IN ('SecondHalf','FullDay') OR @cur_leave IN ('SecondHalf','FullDay') OR @cur_onduty IN ('SecondHalf','FullDay') THEN
                SET @final_deduct = 0.00;
            END IF;
        ELSEIF v_reg_shift = 'SecondHalf' THEN
            IF @cur_shift IN ('FirstHalf','FullDay') OR @cur_leave IN ('FirstHalf','FullDay') OR @cur_onduty IN ('FirstHalf','FullDay') THEN
                SET @final_deduct = 0.00;
            END IF;
        END IF;

        -- If over limit, add penalty
        IF v_approved_count >= v_limit THEN
            SET @final_deduct = LEAST(1.0, @final_deduct + 0.50);
        END IF;

        UPDATE attendance_daily 
        SET status = 'Present', 
            regularization_shift_type = v_reg_shift, 
            deduction_days = @final_deduct
        WHERE employee_id = v_emp_id AND date = v_date;
    
    ELSEIF v_type = 'OnDuty' THEN
        UPDATE attendance_daily 
        SET status = 'Present', 
            onduty_shift_type = v_reg_shift, 
            deduction_days = 0.00,
            first_in_time = IF(v_reg_shift IN ('FullDay', 'FirstHalf'), '09:00:00', first_in_time),
            last_out_time = IF(v_reg_shift IN ('FullDay', 'SecondHalf'), '17:00:00', last_out_time)
        WHERE employee_id = v_emp_id AND date = v_date;
    END IF;
    
    SELECT 'Success' as result;
END //

-- Get Attendance Summary for Dashboard
DROP PROCEDURE IF EXISTS `sp_get_attendance_summary` //
CREATE PROCEDURE `sp_get_attendance_summary`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        COUNT(CASE WHEN UPPER(status) = 'PRESENT' THEN 1 END) AS present_count,
        COUNT(CASE WHEN UPPER(status) = 'ABSENT' THEN 1 END) AS absent_count,
        SUM(is_late) AS late_count,
        SUM(is_early_leaving) AS early_leaving_count,
        SUM(CASE WHEN regularization_shift_type IS NOT NULL THEN 1 ELSE 0 END) AS regularized_count,
        SUM(CASE WHEN onduty_shift_type IS NOT NULL THEN 1 ELSE 0 END) AS onduty_count,
        SUM(CASE 
            WHEN is_leave = 1 AND (leave_shift_type = 'FullDay' OR leave_shift_type IS NULL) THEN 1.0
            WHEN is_leave = 1 AND (leave_shift_type = 'FirstHalf' OR leave_shift_type = 'SecondHalf') THEN 0.5
            ELSE 0 
        END) AS leave_days,
        SUM(deduction_days) AS total_deductions
    FROM attendance_daily
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year;
END //

-- Request Attendance Adjustment with Validation
DROP PROCEDURE IF EXISTS `sp_request_attendance_adjustment` //
CREATE PROCEDURE `sp_request_attendance_adjustment`(
    IN p_employee_id INT,
    IN p_type ENUM('Regularization', 'OnDuty'),
    IN p_date DATE,
    IN p_shift_type ENUM('FullDay', 'FirstHalf', 'SecondHalf'),
    IN p_remarks TEXT,
    IN p_attachment_path VARCHAR(512)
)
BEGIN
    -- Validation for Regularization
    IF p_type = 'Regularization' THEN
        -- Check if regularization is actually needed
        IF EXISTS (
            SELECT 1 FROM attendance_daily 
            WHERE employee_id = p_employee_id AND date = p_date
            AND status = 'Present' 
            AND (
                (p_shift_type = 'FullDay' AND is_late = 0 AND is_early_leaving = 0) OR
                (p_shift_type = 'FirstHalf' AND is_late = 0) OR
                (p_shift_type = 'SecondHalf' AND is_early_leaving = 0)
            )
        ) THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Regularization is not required for this shift as attendance is already marked on-time.';
        END IF;

        IF p_date > CURRENT_DATE THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Regularization cannot be requested for future dates.';
        END IF;
    END IF;

    INSERT INTO attendance_regularization (
        employee_id, request_type, date, regularization_shift_type, reason, attachment_path, status, requested_on
    ) VALUES (
        p_employee_id, p_type, p_date, p_shift_type, p_remarks, p_attachment_path, 'Pending', NOW()
    );
    
    SELECT LAST_INSERT_ID() AS id;
END //

-- Get Adjustment History for Employee with Filters
DROP PROCEDURE IF EXISTS `sp_get_employee_adjustments` //
CREATE PROCEDURE `sp_get_employee_adjustments`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        aj.*,
        e.employee_name as approver_name
    FROM attendance_adjustments aj
    LEFT JOIN employee e ON aj.approved_by_id = e.employee_id
    WHERE aj.employee_id = p_employee_id
      AND (p_month IS NULL OR MONTH(aj.date) = p_month)
      AND (p_year IS NULL OR YEAR(aj.date) = p_year)
    ORDER BY aj.requested_on DESC;
END //

-- Get Attendance History for Employee
DROP PROCEDURE IF EXISTS `sp_get_employee_attendance` //
CREATE PROCEDURE `sp_get_employee_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT * 
    FROM attendance 
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year
    ORDER BY date DESC, punch_time ASC;
END //

DELIMITER ;
