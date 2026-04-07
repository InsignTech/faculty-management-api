-- Migration: Cleanup Employee Table and SPs
-- Removing employee_type (Category) in favor of Role-based entitlements
USE `staffdesk`;

DELIMITER //

-- 1. Update sp_create_employee: remove p_employee_type
DROP PROCEDURE IF EXISTS `sp_create_employee` //
CREATE PROCEDURE `sp_create_employee`(
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
    IN p_email VARCHAR(200),
    IN p_role_id INT,
    IN p_designation_id INT,
    IN p_reporting_manager_id INT,
    IN p_joining_date DATE,
    IN p_active TINYINT,
    IN p_created_by VARCHAR(45),
    IN p_department_id INT,
    IN p_basic_pay DECIMAL(15,2)
)
BEGIN
    INSERT INTO employee (
        organization_id, employee_code, employee_name, email, role_id, 
        designation_id, reporting_manager_id, 
        joining_date, active, created_by, created_on, department_id, basic_pay
    ) VALUES (
        p_organization_id, p_employee_code, p_employee_name, p_email, p_role_id, 
        p_designation_id, p_reporting_manager_id, 
        p_joining_date, p_active, p_created_by, NOW(), p_department_id, p_basic_pay
    );

    SELECT LAST_INSERT_ID() AS employee_id;
END //

-- 2. Update sp_update_employee: remove p_employee_type
DROP PROCEDURE IF EXISTS `sp_update_employee` //
CREATE PROCEDURE `sp_update_employee`(
    IN p_employee_id INT,
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
    IN p_email VARCHAR(200),
    IN p_role_id INT,
    IN p_designation_id INT,
    IN p_reporting_manager_id INT,
    IN p_joining_date DATE,
    IN p_active TINYINT,
    IN p_modified_by VARCHAR(45),
    IN p_department_id INT,
    IN p_basic_pay DECIMAL(15,2)
)
BEGIN
    UPDATE employee SET
        organization_id = p_organization_id,
        employee_code = p_employee_code,
        employee_name = p_employee_name,
        email = p_email,
        role_id = p_role_id,
        designation_id = p_designation_id,
        reporting_manager_id = p_reporting_manager_id,
        joining_date = p_joining_date,
        active = p_active,
        modified_by = p_modified_by,
        modified_on = NOW(),
        department_id = p_department_id,
        basic_pay = p_basic_pay
    WHERE employee_id = p_employee_id;

    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;

-- Optional: Drop the column if you want a clean break, 
-- but keeping it for now to avoid data loss if ever needed back.
-- ALTER TABLE employee DROP COLUMN employee_type;
