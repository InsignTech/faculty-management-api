-- Stored Procedures for Backend Filtering of Employees and Managers

USE `staffdesk`;

DELIMITER //

-- Procedure to get filtered employees for the main listing
DROP PROCEDURE IF EXISTS `sp_get_employees_filtered` //
CREATE PROCEDURE `sp_get_employees_filtered`(
    IN p_search_term VARCHAR(255),
    IN p_role_id INT
)
BEGIN
    SELECT 
        e.*,
        u.email,
        d.departmentname,
        r.role AS role_name
    FROM employee e
    LEFT JOIN user_accounts u ON e.user_id = u.id
    LEFT JOIN department d ON e.department_id = d.department_id
    LEFT JOIN app_role r ON e.role_id = r.role_id
    WHERE 
        (p_search_term IS NULL OR p_search_term = '' OR e.employee_name LIKE CONCAT('%', p_search_term, '%') OR e.employee_code LIKE CONCAT('%', p_search_term, '%'))
        AND (p_role_id IS NULL OR p_role_id = 0 OR e.role_id = p_role_id)
    ORDER BY e.employee_id DESC;
END //

-- Procedure to get potential managers with filtering
DROP PROCEDURE IF EXISTS `sp_get_potential_managers` //
CREATE PROCEDURE `sp_get_potential_managers`(
    IN p_search_term VARCHAR(255),
    IN p_department_id INT,
    IN p_exclude_employee_id INT
)
BEGIN
    SELECT 
        e.employee_id,
        e.employee_name AS name,
        d.departmentname AS dept,
        e.department_id
    FROM employee e
    LEFT JOIN department d ON e.department_id = d.department_id
    WHERE 
        e.employee_id != p_exclude_employee_id -- Can't be own manager
        AND (p_search_term IS NULL OR p_search_term = '' OR e.employee_name LIKE CONCAT('%', p_search_term, '%'))
        AND (p_department_id IS NULL OR p_department_id = 0 OR e.department_id = p_department_id)
    ORDER BY e.employee_name ASC;
END //

DELIMITER ;
