-- Migration Script: Fix Employee Uniqueness and Email
-- Run this in your MySQL database 'staffdesk'

USE `staffdesk`;

-- 1. Add email column to employee table (if not exists)
-- Using a procedure to safely add column and constraints
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `sp_migrate_employee_table`()
BEGIN
    -- Add email column if it doesn't exist
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = 'staffdesk' AND table_name = 'employee' AND column_name = 'email') THEN
        ALTER TABLE employee ADD COLUMN email VARCHAR(255) AFTER employee_name;
    END IF;

    -- Add UNIQUE constraint to employee_code if not already unique
    IF NOT EXISTS (SELECT * FROM information_schema.statistics WHERE table_schema = 'staffdesk' AND table_name = 'employee' AND index_name = 'idx_employee_code_unique') THEN
        ALTER TABLE employee ADD CONSTRAINT idx_employee_code_unique UNIQUE (employee_code);
    END IF;

    -- Add UNIQUE constraint to email if not already unique
    IF NOT EXISTS (SELECT * FROM information_schema.statistics WHERE table_schema = 'staffdesk' AND table_name = 'employee' AND index_name = 'idx_employee_email_unique') THEN
        ALTER TABLE employee ADD CONSTRAINT idx_employee_email_unique UNIQUE (email);
    END IF;
END //
DELIMITER ;

CALL `sp_migrate_employee_table`();
DROP PROCEDURE `sp_migrate_employee_table`;

-- 2. Update sp_create_employee to handle email and check for duplicates
DROP PROCEDURE IF EXISTS `sp_create_employee`;
DELIMITER //
CREATE PROCEDURE `sp_create_employee`(
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
    IN p_email VARCHAR(255),
    IN p_role_id INT,
    IN p_designation_id INT,
    IN p_employee_type VARCHAR(45),
    IN p_reporting_manager_id INT,
    IN p_joining_date DATE,
    IN p_active TINYINT,
    IN p_created_by VARCHAR(45),
    IN p_department_id INT
)
BEGIN
    -- Check if employee_code already exists
    IF EXISTS (SELECT 1 FROM employee WHERE employee_code = p_employee_code) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Employee code already exists';
    END IF;

    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM employee WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Email already exists';
    END IF;

    INSERT INTO employee (
        organization_id, employee_code, employee_name, email, role_id, 
        designation_id, employee_type, reporting_manager_id, 
        joining_date, active, created_by, created_on, department_id
    ) VALUES (
        p_organization_id, p_employee_code, p_employee_name, p_email, p_role_id, 
        p_designation_id, p_employee_type, p_reporting_manager_id, 
        p_joining_date, p_active, p_created_by, NOW(), p_department_id
    );

    SELECT LAST_INSERT_ID() AS employee_id;
END //
DELIMITER ;

-- 3. Update sp_get_employees to include email
DROP PROCEDURE IF EXISTS `sp_get_employees`;
DELIMITER //
CREATE PROCEDURE `sp_get_employees`()
BEGIN
    SELECT 
        e.*,
        d.departmentname,
        r.role AS role_name,
        des.designation AS designation_name,
        m.employee_name AS manager_name
    FROM employee e
    LEFT JOIN department d ON e.department_id = d.department_id
    LEFT JOIN app_role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
    ORDER BY e.employee_id DESC;
END //
DELIMITER ;

-- 4. Update sp_get_employee_by_id to include email
DROP PROCEDURE IF EXISTS `sp_get_employee_by_id`;
DELIMITER //
CREATE PROCEDURE `sp_get_employee_by_id`(
    IN p_employee_id INT
)
BEGIN
    SELECT 
        e.*,
        d.departmentname,
        r.role AS role_name,
        des.designation AS designation_name,
        m.employee_name AS manager_name
    FROM employee e
    LEFT JOIN department d ON e.department_id = d.department_id
    LEFT JOIN app_role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
    WHERE e.employee_id = p_employee_id;
END //
DELIMITER ;

-- 5. Update sp_update_employee to handle email
DROP PROCEDURE IF EXISTS `sp_update_employee`;
DELIMITER //
CREATE PROCEDURE `sp_update_employee`(
    IN p_employee_id INT,
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
    IN p_email VARCHAR(255),
    IN p_role_id INT,
    IN p_designation_id INT,
    IN p_employee_type VARCHAR(45),
    IN p_reporting_manager_id INT,
    IN p_joining_date DATE,
    IN p_active TINYINT,
    IN p_modified_by VARCHAR(45),
    IN p_department_id INT
)
BEGIN
    UPDATE employee SET
        organization_id = p_organization_id,
        employee_code = p_employee_code,
        employee_name = p_employee_name,
        email = p_email,
        role_id = p_role_id,
        designation_id = p_designation_id,
        employee_type = p_employee_type,
        reporting_manager_id = p_reporting_manager_id,
        joining_date = p_joining_date,
        active = p_active,
        modified_by = p_modified_by,
        modified_on = NOW(),
        department_id = p_department_id
    WHERE employee_id = p_employee_id;

    SELECT ROW_COUNT() AS affected_rows;
END //
DELIMITER ;
