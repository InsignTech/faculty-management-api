DROP PROCEDURE IF EXISTS `sp_update_employee`;

DELIMITER ;;
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
    IN p_basic_pay DECIMAL(15,2),
    IN p_employee_type VARCHAR(45),
    IN p_employment_status VARCHAR(45),
    IN p_status_effective_date DATE,
    IN p_remarks VARCHAR(500)
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
        basic_pay = p_basic_pay,
        employee_type = p_employee_type,
        employment_status = p_employment_status,
        status_effective_date = p_status_effective_date,
        remarks = p_remarks
    WHERE employee_id = p_employee_id;

    -- Sync active status to user accounts
    UPDATE user_accounts SET active = p_active WHERE employee_id = p_employee_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
