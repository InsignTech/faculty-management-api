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

-- Handle Regularization Approval (3-Chance Rule)
DROP PROCEDURE IF EXISTS `sp_handle_regularization_approval` //
CREATE PROCEDURE `sp_handle_regularization_approval`(
    IN p_adjustment_id INT,
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_date DATE;
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_approved_count INT;
    
    -- Get adjustment details
    SELECT employee_id, date INTO v_emp_id, v_date FROM attendance_adjustments WHERE adjustment_id = p_adjustment_id;
    SET v_month = MONTH(v_date);
    SET v_year = YEAR(v_date);
    
    -- Count previous approved regularizations this month
    SELECT COUNT(*) INTO v_approved_count 
    FROM attendance_adjustments 
    WHERE employee_id = v_emp_id 
      AND MONTH(date) = v_month 
      AND YEAR(date) = v_year 
      AND status = 'Approved'
      AND type = 'Regularization';
      
    -- Update adjustment status
    UPDATE attendance_adjustments 
    SET status = 'Approved', 
        approved_by_id = p_approver_id, 
        approved_on = NOW(),
        remarks = p_remarks
    WHERE adjustment_id = p_adjustment_id;
    
    -- Update attendance table based on the rule (first 3 are free)
    IF v_approved_count < 3 THEN
        UPDATE attendance 
        SET is_regularized = 1, deduction_days = 0.00 
        WHERE employee_id = v_emp_id AND date = v_date;
    ELSE
        UPDATE attendance 
        SET is_regularized = 1, deduction_days = 0.50 
        WHERE employee_id = v_emp_id AND date = v_date;
    END IF;
    
    SELECT v_approved_count + 1 AS monthly_approved_count;
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

-- Request Attendance Adjustment
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
    INSERT INTO attendance_adjustments (
        employee_id, type, date, punch_time, remarks, attachment_path, status, requested_on
    ) VALUES (
        p_employee_id, p_type, p_date, p_punch_time, p_remarks, p_attachment_path, 'Pending', NOW()
    );
    
    SELECT LAST_INSERT_ID() AS adjustment_id;
END //

-- Get Adjustment History for Employee
DROP PROCEDURE IF EXISTS `sp_get_employee_adjustments` //
CREATE PROCEDURE `sp_get_employee_adjustments`(
    IN p_employee_id INT
)
BEGIN
    SELECT 
        aj.*,
        e.employee_name as approver_name
    FROM attendance_adjustments aj
    LEFT JOIN employee e ON aj.approved_by_id = e.employee_id
    WHERE aj.employee_id = p_employee_id
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
