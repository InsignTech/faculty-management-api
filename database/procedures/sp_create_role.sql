DROP PROCEDURE IF EXISTS `sp_create_role`;

DELIMITER ;;
CREATE PROCEDURE `sp_create_role`(
    IN p_role VARCHAR(45)
)
BEGIN
    INSERT INTO app_role(role) VALUES(p_role);
    SELECT LAST_INSERT_ID() AS role_id, p_role AS role;
END ;;
DELIMITER ;
