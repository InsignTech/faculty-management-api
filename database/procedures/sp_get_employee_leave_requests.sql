DROP PROCEDURE IF EXISTS `sp_get_employee_leave_requests`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_employee_leave_requests`(
    IN p_employee_id INT
)
BEGIN
    SELECT
        lr.*,
        e.employee_name as approver_name
    FROM leave_requests lr
    LEFT JOIN employee e ON lr.approved_by_id = e.employee_id
    WHERE lr.employee_id = p_employee_id
    ORDER BY lr.applied_on DESC;
END ;;
DELIMITER ;
