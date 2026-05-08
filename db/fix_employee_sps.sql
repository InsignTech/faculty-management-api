-- Consolidated Fix for Employee Stored Procedures (V3)
-- Run this script to align SPs with the current employee table schema

USE `staffdesk`;

DELIMITER //

-- 1. Get All Employees (0 arguments)
DROP PROCEDURE IF EXISTS `sp_get_employees` //
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

-- 2. Get Employee By ID
DROP PROCEDURE IF EXISTS `sp_get_employee_by_id` //
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

-- 3. Get Filtered Employees (3 arguments)
DROP PROCEDURE IF EXISTS `sp_get_employees_filtered` //
CREATE PROCEDURE `sp_get_employees_filtered`(
    IN p_search_term VARCHAR(255),
    IN p_role_id INT,
    IN p_active_only TINYINT
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
    WHERE 
        (p_search_term IS NULL OR p_search_term = '' OR e.employee_name LIKE CONCAT('%', p_search_term, '%') OR e.employee_code LIKE CONCAT('%', p_search_term, '%'))
        AND (p_role_id IS NULL OR p_role_id = 0 OR e.role_id = p_role_id)
        AND (p_active_only = 0 OR e.active = 1)
    ORDER BY e.employee_id DESC;
END //

-- 4. Create Employee
DROP PROCEDURE IF EXISTS `sp_create_employee` //
CREATE PROCEDURE `sp_create_employee`(
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
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
    INSERT INTO employee (
        organization_id, employee_code, employee_name, role_id, 
        designation_id, employee_type, reporting_manager_id, 
        joining_date, active, created_by, created_on, department_id
    ) VALUES (
        p_organization_id, p_employee_code, p_employee_name, p_role_id, 
        p_designation_id, p_employee_type, p_reporting_manager_id, 
        p_joining_date, p_active, p_created_by, NOW(), p_department_id
    );

    SELECT LAST_INSERT_ID() AS employee_id;
END //

-- 5. Update Employee
DROP PROCEDURE IF EXISTS `sp_update_employee` //
CREATE PROCEDURE `sp_update_employee`(
    IN p_employee_id INT,
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
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

    -- SYNC ACTIVE STATUS TO USER ACCOUNT
    UPDATE user_accounts SET active = p_active WHERE employee_id = p_employee_id;

    SELECT ROW_COUNT() AS affected_rows;
END //

-- 6. Get Potential Managers
DROP PROCEDURE IF EXISTS `sp_get_potential_managers` //
CREATE PROCEDURE `sp_get_potential_managers`(
    IN p_search_term VARCHAR(255),
    IN p_department_id INT,
    IN p_exclude_employee_id INT
)
BEGIN
    SELECT 
        e.employee_id,
        e.employee_code AS code,
        e.employee_name AS name,
        d.departmentname AS dept,
        e.department_id,
        r.role AS role_name
    FROM employee e
    LEFT JOIN department d ON e.department_id = d.department_id
    LEFT JOIN app_role r ON e.role_id = r.role_id
    WHERE 
        e.employee_id != p_exclude_employee_id
        AND e.active = 1
        AND (p_search_term IS NULL OR p_search_term = '' 
             OR e.employee_name LIKE CONCAT('%', p_search_term, '%') 
             OR e.employee_code LIKE CONCAT('%', p_search_term, '%'))
        AND (p_department_id IS NULL OR p_department_id = 0 OR e.department_id = p_department_id)
    ORDER BY e.employee_name ASC;
END //

DELIMITER ;
