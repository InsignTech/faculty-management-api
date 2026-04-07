-- 1. Add basic_pay to employee table
ALTER TABLE employee ADD COLUMN IF NOT EXISTS `basic_pay` DECIMAL(15,2) DEFAULT 0.00;

-- 1.1 Update Leave Policy Tables for Weekly-Off
ALTER TABLE leave_policy_system ADD COLUMN IF NOT EXISTS `weekly_off` TEXT DEFAULT '["Sunday"]';
ALTER TABLE leave_policy_designation ADD COLUMN IF NOT EXISTS `weekly_off` TEXT NULL;
ALTER TABLE leave_policy_employee ADD COLUMN IF NOT EXISTS `weekly_off` TEXT NULL;

-- 2. Create holidays table
CREATE TABLE IF NOT EXISTS `holidays` (
    `holiday_id` INT AUTO_INCREMENT PRIMARY KEY,
    `holiday_date` DATE NOT NULL UNIQUE,
    `description` VARCHAR(255),
    `is_active` TINYINT DEFAULT 1,
    `created_on` DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create attendance_settings table
CREATE TABLE IF NOT EXISTS `attendance_settings` (
    `setting_id` INT AUTO_INCREMENT PRIMARY KEY,
    `setting_key` VARCHAR(100) UNIQUE NOT NULL,
    `setting_value` VARCHAR(255) NOT NULL,
    `description` VARCHAR(255)
);

-- 4. Modify attendance table structure
-- We wrap this in a procedure to safely add columns if they don't exist
DROP PROCEDURE IF EXISTS `sp_tmp_migrate_attendance_v1`;
DELIMITER //
CREATE PROCEDURE `sp_tmp_migrate_attendance_v1`()
BEGIN
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = 'staffdesk' AND table_name = 'attendance' AND column_name = 'is_late') THEN
        ALTER TABLE attendance 
        ADD COLUMN is_late TINYINT DEFAULT 0,
        ADD COLUMN is_early_leaving TINYINT DEFAULT 0,
        ADD COLUMN is_regularized TINYINT DEFAULT 0,
        ADD COLUMN deduction_days DECIMAL(3,2) DEFAULT 0.00;
    END IF;
END //
DELIMITER ;
CALL `sp_tmp_migrate_attendance_v1`();
DROP PROCEDURE `sp_tmp_migrate_attendance_v1`;

-- 5. Create leave_encashments table
CREATE TABLE IF NOT EXISTS `leave_encashments` (
    `encashment_id` INT AUTO_INCREMENT PRIMARY KEY,
    `employee_id` INT NOT NULL,
    `leave_type` VARCHAR(50) NOT NULL,
    `days_to_encash` DECIMAL(5,2) NOT NULL,
    `encashment_amount` DECIMAL(15,2) NOT NULL,
    `status` ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Pending',
    `requested_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `approved_by_id` INT NULL,
    `approved_on` DATETIME NULL,
    `remarks` TEXT,
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id)
);

-- 6. Seed default settings for M.E.S.T.O. Abdulla Memorial College
INSERT INTO `attendance_settings` (setting_key, setting_value, description) VALUES
('standard_in_time', '09:00:00', 'Official morning punch-in time'),
('grace_in_time', '09:15:00', 'Punch-in allowed without being marked as Late'),
('standard_out_time', '16:30:00', 'Official evening punch-out time'),
('early_out_threshold', '16:05:00', 'Punch-out before this time is marked as Early Leaving'),
('max_waived_instances', '3', 'Max number of regularized Late/Early instances allowed per month before deduction'),
('deduction_amount', '0.5', 'Deduction in days for each unregularized or excess late/early instance')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 7. Add Sunday as a default holiday or weekly_off
INSERT IGNORE INTO `holidays` (holiday_date, description) VALUES
('2026-04-05', 'Sunday'),
('2026-04-12', 'Sunday'),
('2026-04-19', 'Sunday'),
('2026-04-26', 'Sunday');

SELECT 'Migration Phase 1 Completed Successfully' AS status;
