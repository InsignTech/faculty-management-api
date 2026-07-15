DROP PROCEDURE IF EXISTS `sp_get_designation_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_designation_policy`(
    IN p_designation_id INT
)
BEGIN
    SELECT lpd.*, lp.policy_name, lp.policy_year
    FROM leave_policy_designation lpd
    JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
    WHERE lpd.designation_id = p_designation_id AND lpd.active = 1;
END ;;
DELIMITER ;
