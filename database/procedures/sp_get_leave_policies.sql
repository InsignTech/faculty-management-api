DROP PROCEDURE IF EXISTS `sp_get_leave_policies`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_leave_policies`()
BEGIN
    SELECT * FROM leave_policy ORDER BY policy_year DESC, created_on DESC;
END ;;
DELIMITER ;
