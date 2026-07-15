DROP PROCEDURE IF EXISTS `sp_get_employee_by_id`;

DELIMITER ;;
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
END ;;
DELIMITER ;
