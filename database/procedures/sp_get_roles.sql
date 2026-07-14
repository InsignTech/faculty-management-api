DROP PROCEDURE IF EXISTS `sp_get_roles`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_roles`()
BEGIN
    SELECT role_id, role FROM app_role ORDER BY role ASC;
END ;;
DELIMITER ;
