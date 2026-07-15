DROP PROCEDURE IF EXISTS `sp_get_role_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_role_policy`(
    IN p_role_id INT
)
BEGIN
    SELECT 
        lpr.*,
        lp.policy_name,
        lp.policy_year
    FROM leave_policy_role lpr
    JOIN leave_policy lp ON lpr.leave_policy_id = lp.leave_policy_id
    WHERE lpr.role_id = p_role_id AND lpr.active = 1;
END ;;
DELIMITER ;
