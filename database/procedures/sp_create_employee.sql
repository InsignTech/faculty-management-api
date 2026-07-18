DROP PROCEDURE IF EXISTS `sp_create_employee`;

DELIMITER ;;
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
    IN p_basic_pay DECIMAL(15,2),
    IN p_employee_type VARCHAR(45),
    IN p_employment_status VARCHAR(45),
    IN p_status_effective_date DATE,
    IN p_remarks VARCHAR(500)
)
BEGIN
    INSERT INTO employee (
        organization_id, employee_code, employee_name, email, role_id, 
        designation_id, reporting_manager_id, 
        joining_date, active, created_by, created_on, department_id, basic_pay,
        employee_type, employment_status, status_effective_date, remarks
    ) VALUES (
        p_organization_id, p_employee_code, p_employee_name, p_email, p_role_id, 
        p_designation_id, p_reporting_manager_id, 
        p_joining_date, p_active, p_created_by, NOW(), p_department_id, p_basic_pay,
        p_employee_type, COALESCE(p_employment_status, 'Active'), p_status_effective_date, p_remarks
    );

    SELECT LAST_INSERT_ID() AS employee_id;
END ;;
DELIMITER ;
