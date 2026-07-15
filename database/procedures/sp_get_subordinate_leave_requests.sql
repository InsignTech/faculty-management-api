DROP PROCEDURE IF EXISTS `sp_get_subordinate_leave_requests`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_subordinate_leave_requests`(
    IN p_manager_id INT,
    IN p_status VARCHAR(50) 
)
BEGIN
    SELECT 
        lr.*,
        e.employee_name,
        e.employee_code,
        r.role_name as employee_role,
        des.designation_name as employee_designation
    FROM leave_requests lr
    JOIN employee e ON lr.employee_id = e.employee_id
    LEFT JOIN role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    WHERE (e.reporting_manager_id = p_manager_id OR p_manager_id IS NULL) 
      AND (p_status IS NULL OR p_status = '' OR lr.status = p_status)
    ORDER BY lr.applied_on DESC;
END ;;
DELIMITER ;
