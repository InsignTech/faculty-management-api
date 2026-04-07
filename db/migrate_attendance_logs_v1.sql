-- 1. Create Sync Logging Table
CREATE TABLE IF NOT EXISTS `attendance_sync_logs` (
    `sync_id` INT NOT NULL AUTO_INCREMENT,
    `start_time` DATETIME NOT NULL,
    `end_time` DATETIME NULL,
    `total_records` INT DEFAULT 0,
    `status` ENUM('Success', 'Failed') DEFAULT 'Success',
    `error_message` TEXT NULL,
    `payload_preview` TEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`sync_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Restructure attendance_detail_log
-- First, add the new column
ALTER TABLE `attendance_detail_log` ADD COLUMN `punch_time` DATETIME AFTER `employee_id`;

-- Migrate existing data (merging date and time)
SET SQL_SAFE_UPDATES = 0;
UPDATE `attendance_detail_log` SET `punch_time` = CAST(CONCAT(`date`, ' ', `time`) AS DATETIME);
SET SQL_SAFE_UPDATES = 1;

-- Remove old columns
ALTER TABLE `attendance_detail_log` DROP COLUMN `date`, DROP COLUMN `time`;

-- Add UNIQUE constraint to prevent duplicates from machine team
ALTER TABLE `attendance_detail_log` ADD UNIQUE KEY `idx_emp_punch` (`employee_id`, `punch_time`);

-- 3. Update Stored Procedure for Daily Processing
DELIMITER //

DROP PROCEDURE IF EXISTS `sp_process_attendance_logs` //
CREATE PROCEDURE `sp_process_attendance_logs`(
    IN p_date DATE
)
BEGIN
    DECLARE v_grace_in TIME;
    DECLARE v_early_out TIME;
    DECLARE v_deduction_amount DECIMAL(3,2);
    
    -- Load settings for thresholds
    SELECT setting_value INTO v_grace_in FROM attendance_settings WHERE setting_key = 'grace_in_time';
    SELECT setting_value INTO v_early_out FROM attendance_settings WHERE setting_key = 'early_out_threshold';
    SELECT CAST(setting_value AS DECIMAL(3,2)) INTO v_deduction_amount FROM attendance_settings WHERE setting_key = 'deduction_amount';

    -- 1. Process Punch-Ins (Earliest punch of the day)
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_late, deduction_days)
    SELECT 
        employee_id, 
        DATE(punch_time), 
        'Present', 
        'Biometric', 
        'PunchIn', 
        'Full Day', 
        MIN(TIME(punch_time)),
        IF(MIN(TIME(punch_time)) > v_grace_in, 1, 0),
        IF(MIN(TIME(punch_time)) > v_grace_in, v_deduction_amount, 0.00)
    FROM attendance_detail_log
    WHERE DATE(punch_time) = p_date
    GROUP BY employee_id, DATE(punch_time)
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_late = VALUES(is_late),
        deduction_days = VALUES(deduction_days),
        status = 'Present';

    -- 2. Process Punch-Outs (Latest punch of the day, if more than one)
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_early_leaving, deduction_days)
    SELECT 
        employee_id, 
        DATE(punch_time), 
        'Present', 
        'Biometric', 
        'PunchOut', 
        'Full Day', 
        MAX(TIME(punch_time)),
        IF(MAX(TIME(punch_time)) < v_early_out, 1, 0),
        IF(MAX(TIME(punch_time)) < v_early_out, v_deduction_amount, 0.00)
    FROM attendance_detail_log
    WHERE DATE(punch_time) = p_date
    GROUP BY employee_id, DATE(punch_time)
    HAVING COUNT(*) > 1
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_early_leaving = VALUES(is_early_leaving),
        deduction_days = GREATEST(deduction_days, VALUES(deduction_days)),
        status = 'Present';
        
    SELECT ROW_COUNT() AS processed_rows;
END //

DELIMITER ;
