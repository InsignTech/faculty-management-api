USE `staffdesk`;

-- Procedure to safely add weekly_off if missing
DROP PROCEDURE IF EXISTS `sp_fix_leave_tables_v1`;
DELIMITER //
CREATE PROCEDURE `sp_fix_leave_tables_v1`()
BEGIN
    -- 1. Ensure master leave_policy table exists
    CREATE TABLE IF NOT EXISTS `leave_policy` (
        `leave_policy_id` INT AUTO_INCREMENT PRIMARY KEY,
        `policy_name` VARCHAR(245) NOT NULL,
        `policy_year` INT NOT NULL,
        `policy_value` LONGTEXT NOT NULL,
        `active` TINYINT DEFAULT 0,
        `created_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
        `created_by` VARCHAR(45)
    );

    -- 2. Ensure leave_policy_system exists and has weekly_off
    CREATE TABLE IF NOT EXISTS `leave_policy_system` (
        `leave_policy_system_id` INT AUTO_INCREMENT PRIMARY KEY,
        `leave_policy_id` INT NOT NULL,
        `policy_value` LONGTEXT NOT NULL,
        `active` TINYINT DEFAULT 1,
        `created_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
        `created_by` VARCHAR(45),
        `policy_year` INT NOT NULL,
        FOREIGN KEY (`leave_policy_id`) REFERENCES `leave_policy` (`leave_policy_id`)
    );
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = 'staffdesk' AND table_name = 'leave_policy_system' AND column_name = 'weekly_off') THEN
        ALTER TABLE leave_policy_system ADD COLUMN weekly_off TEXT;
    END IF;

    -- 3. Ensure leave_policy_designation exists and has weekly_off
    CREATE TABLE IF NOT EXISTS `leave_policy_designation` (
        `leave_policy_designation_id` INT AUTO_INCREMENT PRIMARY KEY,
        `leave_policy_id` INT NOT NULL,
        `designation_id` INT NOT NULL,
        `policy_value` LONGTEXT NOT NULL,
        `active` TINYINT DEFAULT 1,
        `created_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
        `created_by` VARCHAR(45),
        FOREIGN KEY (`leave_policy_id`) REFERENCES `leave_policy` (`leave_policy_id`)
    );
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = 'staffdesk' AND table_name = 'leave_policy_designation' AND column_name = 'weekly_off') THEN
        ALTER TABLE leave_policy_designation ADD COLUMN weekly_off TEXT;
    END IF;

    -- 4. Ensure leave_policy_employee exists and has weekly_off
    CREATE TABLE IF NOT EXISTS `leave_policy_employee` (
        `leave_policy_employee_id` INT AUTO_INCREMENT PRIMARY KEY,
        `leave_policy_id` INT NOT NULL,
        `employee_id` INT NOT NULL,
        `policy_value` LONGTEXT NOT NULL,
        `active` TINYINT DEFAULT 1,
        `created_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
        `created_by` VARCHAR(45),
        FOREIGN KEY (`leave_policy_id`) REFERENCES `leave_policy` (`leave_policy_id`),
        FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
    );
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = 'staffdesk' AND table_name = 'leave_policy_employee' AND column_name = 'weekly_off') THEN
        ALTER TABLE leave_policy_employee ADD COLUMN weekly_off TEXT;
    END IF;

    -- 5. Ensure leave_requests exists
    CREATE TABLE IF NOT EXISTS `leave_requests` (
        `leave_request_id` INT AUTO_INCREMENT PRIMARY KEY,
        `employee_id` INT NOT NULL,
        `leave_type` VARCHAR(50) NOT NULL,
        `start_date` DATE NOT NULL,
        `end_date` DATE NOT NULL,
        `total_days` DECIMAL(5,2) NOT NULL,
        `reason` TEXT,
        `attachment_path` VARCHAR(512),
        `status` ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Pending',
        `applied_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
        `approved_by_id` INT NULL,
        `approved_on` DATETIME NULL,
        FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
    );
END //
DELIMITER ;

-- Run the fix
CALL `sp_fix_leave_tables_v1`();
DROP PROCEDURE `sp_fix_leave_tables_v1`;

-- 6. Seed/Update Default 2026 Policy
INSERT INTO `leave_policy` (policy_name, policy_year, policy_value, active, created_by)
VALUES ('Standard College Policy 2026', 2026, '[{"leaveType": "Casual Leave", "leaveCount": 12}, {"leaveType": "Sick Leave", "leaveCount": 10}, {"leaveType": "Earned Leave", "leaveCount": 15}]', 1, 'Admin')
ON DUPLICATE KEY UPDATE active = 1;

-- Ensure the system level baseline refers to this policy
SET @last_policy_id = (SELECT leave_policy_id FROM leave_policy WHERE policy_year = 2026 LIMIT 1);

INSERT INTO `leave_policy_system` (leave_policy_id, policy_value, policy_year, active, created_by, weekly_off)
VALUES (@last_policy_id, '[{"leaveType": "Casual Leave", "leaveCount": 12}, {"leaveType": "Sick Leave", "leaveCount": 10}, {"leaveType": "Earned Leave", "leaveCount": 15}]', 2026, 1, 'Admin', '["Sunday"]')
ON DUPLICATE KEY UPDATE active = 1, weekly_off = '["Sunday"]';
