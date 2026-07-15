DROP PROCEDURE IF EXISTS `sp_get_employee_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_employee_policy`(
    IN p_employee_id INT
)
BEGIN
    SELECT lpe.*, lp.policy_name, lp.policy_year
    FROM leave_policy_employee lpe
    JOIN leave_policy lp ON lpe.leave_policy_id = lp.leave_policy_id
    WHERE lpe.employee_id = p_employee_id AND lpe.active = 1;
END ;;
DELIMITER ;
