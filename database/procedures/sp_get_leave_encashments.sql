DROP PROCEDURE IF EXISTS `sp_get_leave_encashments`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_leave_encashments`(
    IN p_employee_id INT
)
BEGIN
    SELECT
        le.*,
        e.employee_name as approver_name
    FROM leave_encashments le
    LEFT JOIN employee e ON le.approved_by_id = e.employee_id
    WHERE le.employee_id = p_employee_id
    ORDER BY le.requested_on DESC;
END ;;
DELIMITER ;
