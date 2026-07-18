DROP PROCEDURE IF EXISTS `sp_get_employees_filtered`;

DELIMITER ;;
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
        TRIM(CONCAT(COALESCE(m.title, ''), ' ', m.employee_name)) AS manager_name
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
END ;;
DELIMITER ;
