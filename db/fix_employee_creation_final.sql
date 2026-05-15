-- Final Fix for Employee Creation Stored Procedure
-- Matches the parameter order and count expected by EmployeeModel.js

USE `staffdesk`;

DROP PROCEDURE IF EXISTS `sp_create_employee`;

DELIMITER //

CREATE PROCEDURE `sp_create_employee`(
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
    IN p_email VARCHAR(255),
    IN p_role_id INT,
    IN p_designation_id INT,
    IN p_reporting_manager_id INT,
    IN p_joining_date DATE,
    IN p_active TINYINT,
    IN p_created_by VARCHAR(45),
    IN p_department_id INT,
    IN p_basic_pay DECIMAL(10,2)
)
BEGIN
    -- Check if employee_code already exists
    IF EXISTS (SELECT 1 FROM employee WHERE employee_code = p_employee_code) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Employee code already exists';
    END IF;

    -- Check if email already exists
    IF p_email IS NOT NULL AND p_email != '' AND EXISTS (SELECT 1 FROM employee WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Email already exists';
    END IF;

    INSERT INTO employee (
        organization_id, 
        employee_code, 
        employee_name, 
        email, 
        role_id, 
        designation_id, 
        reporting_manager_id, 
        joining_date, 
        active, 
        created_by, 
        created_on, 
        department_id,
        basic_pay,
        employee_type
    ) VALUES (
        p_organization_id, 
        p_employee_code, 
        p_employee_name, 
        p_email, 
        p_role_id, 
        p_designation_id, 
        p_reporting_manager_id, 
        p_joining_date, 
        p_active, 
        p_created_by, 
        NOW(), 
        p_department_id,
        p_basic_pay,
        'FULLTIME'
    );

    SELECT LAST_INSERT_ID() AS employee_id;
END //

DROP PROCEDURE IF EXISTS `sp_update_employee` //

CREATE PROCEDURE `sp_update_employee`(
    IN p_employee_id INT,
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
    IN p_email VARCHAR(255),
    IN p_role_id INT,
    IN p_designation_id INT,
    IN p_reporting_manager_id INT,
    IN p_joining_date DATE,
    IN p_active TINYINT,
    IN p_modified_by VARCHAR(45),
    IN p_department_id INT,
    IN p_basic_pay DECIMAL(10,2)
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

    -- SYNC ACTIVE STATUS TO USER ACCOUNT
    UPDATE user_accounts SET active = p_active WHERE employee_id = p_employee_id;

    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;
