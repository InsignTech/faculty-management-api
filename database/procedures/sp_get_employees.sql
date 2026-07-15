DROP PROCEDURE IF EXISTS `sp_get_employees`;

DELIMITER ;;
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
END ;;
DELIMITER ;
