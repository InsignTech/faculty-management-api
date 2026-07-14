DROP PROCEDURE IF EXISTS `sp_get_role_privileges`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_role_privileges`(
    IN p_role_id INT
)
BEGIN
    SELECT 
        rp.app_role_privilege_id,
        rp.role_id,
        rp.settings_id,
        rp.app_privilege_value,
        s.settings_key
    FROM app_role_privilege rp
    JOIN settings s ON rp.settings_id = s.settings_id
    WHERE rp.role_id = p_role_id;
END ;;
DELIMITER ;
