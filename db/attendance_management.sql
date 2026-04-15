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
CREATE TABLE IF NOT EXISTS `attendance_adjustments` (
    `adjustment_id` INT NOT NULL AUTO_INCREMENT,
    `employee_id` INT NOT NULL,
    `type` ENUM('Regularization', 'OnDuty') NOT NULL,
    `requested_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `date` DATE NOT NULL,
    `punch_time` TIME NOT NULL,
    `remarks` TEXT,
    `status` ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Pending',
    `approved_by_id` INT NULL,
    `approved_on` DATETIME NULL,
    `attachment_path` VARCHAR(512) NULL,
    PRIMARY KEY (`adjustment_id`),
    CONSTRAINT `fk_adjustment_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
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
        employee_id, 
        date, 
        'Present', 
        'Biometric', 
        'PunchIn', 
        'Full Day', 
        MIN(time),
        IF(MIN(time) > v_grace_in, 1, 0),
        IF(MIN(time) > v_grace_in, v_deduction_amount, 0.00)
    FROM attendance_detail_log
    WHERE date = p_date
    GROUP BY employee_id, date
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_late = VALUES(is_late),
        deduction_days = VALUES(deduction_days),
        status = 'Present';

    -- 2. Process Punch-Outs
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_early_leaving, deduction_days)
    SELECT 
        employee_id, 
        date, 
        'Present', 
        'Biometric', 
        'PunchOut', 
        'Full Day', 
        MAX(time),
        IF(MAX(time) < v_early_out, 1, 0),
        IF(MAX(time) < v_early_out, v_deduction_amount, 0.00)
    FROM attendance_detail_log
    WHERE date = p_date
    GROUP BY employee_id, date
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
    DECLARE v_type ENUM('Regularization', 'OnDuty');
    DECLARE v_punch_time TIME;
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_approved_count INT;
    
    -- 1. Get adjustment details
    SELECT employee_id, date, type, punch_time 
    INTO v_emp_id, v_date, v_type, v_punch_time 
    FROM attendance_adjustments 
    WHERE adjustment_id = p_adjustment_id;
    
    SET v_month = MONTH(v_date);
    SET v_year = YEAR(v_date);
    
    -- 2. Update status to Approved
    UPDATE attendance_adjustments 
    SET status = 'Approved', 
        approved_by_id = p_approver_id, 
        approved_on = NOW(),
        remarks = CONCAT(COALESCE(remarks, ''), ' | Final Approval: ', p_remarks)
    WHERE adjustment_id = p_adjustment_id;
    
    -- 3. Apply changes to attendance table based on type
    IF v_type = 'Regularization' THEN
        -- Count previous approved regularizations this month
        SELECT COUNT(*) INTO v_approved_count 
        FROM attendance_adjustments 
        WHERE employee_id = v_emp_id 
          AND MONTH(date) = v_month 
          AND YEAR(date) = v_year 
          AND status = 'Approved'
          AND type = 'Regularization'
          AND adjustment_id != p_adjustment_id;
          
        IF v_approved_count < 3 THEN
            UPDATE attendance 
            SET is_regularized = 1, deduction_days = 0.00, status = 'Present'
            WHERE employee_id = v_emp_id AND date = v_date;
        ELSE
            UPDATE attendance 
            SET is_regularized = 1, deduction_days = 0.50, status = 'Present'
            WHERE employee_id = v_emp_id AND date = v_date;
        END IF;
    
    ELSEIF v_type = 'OnDuty' THEN
        -- Mark as Present for both shifts
        INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_regularized, deduction_days)
        VALUES (v_emp_id, v_date, 'Present', 'Onduty', 'PunchIn', 'Full Day', '09:00:00', 1, 0.00)
        ON DUPLICATE KEY UPDATE 
            status = 'Present', punch_type = 'Onduty', punch_time = '09:00:00', is_regularized = 1, deduction_days = 0.00;
            
        INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_regularized, deduction_days)
        VALUES (v_emp_id, v_date, 'Present', 'Onduty', 'PunchOut', 'Full Day', '17:00:00', 1, 0.00)
        ON DUPLICATE KEY UPDATE 
            status = 'Present', punch_type = 'Onduty', punch_time = '17:00:00', is_regularized = 1, deduction_days = 0.00;
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
        COUNT(DISTINCT date) AS total_days_present,
        SUM(is_late) AS late_count,
        SUM(is_early_leaving) AS early_leaving_count,
        SUM(is_regularized) AS regularized_count,
        SUM(deduction_days) AS total_deductions
    FROM attendance
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
    IN p_punch_time TIME,
    IN p_remarks TEXT,
    IN p_attachment_path VARCHAR(512)
)
BEGIN
    -- Validation for Regularization
    IF p_type = 'Regularization' THEN
        -- Check if regularization is actually needed
        -- Not needed if: Has both In and Out, both are Present, and neither is Late nor Early Leaving
        IF EXISTS (
            SELECT 1 FROM attendance 
            WHERE employee_id = p_employee_id AND date = p_date
            AND status = 'Present' 
            AND is_late = 0 AND is_early_leaving = 0
            GROUP BY employee_id, date
            HAVING COUNT(DISTINCT type) = 2
        ) THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Regularization is not required for this date as attendance is already complete and on-time.';
        END IF;

        -- Optional: Prevent future regularizations if needed
        IF p_date > CURRENT_DATE THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Regularization cannot be requested for future dates.';
        END IF;
    END IF;

    INSERT INTO attendance_adjustments (
        employee_id, type, date, punch_time, remarks, attachment_path, status, requested_on
    ) VALUES (
        p_employee_id, p_type, p_date, p_punch_time, p_remarks, p_attachment_path, 'Pending', NOW()
    );
    
    SELECT LAST_INSERT_ID() AS adjustment_id;
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
