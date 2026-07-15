DROP PROCEDURE IF EXISTS `sp_save_role_privilege`;

DELIMITER ;;
CREATE PROCEDURE `sp_save_role_privilege`(
    IN p_role_id INT,
    IN p_settings_id INT,
    IN p_privilege_value JSON
)
BEGIN
    DECLARE v_id INT;
    
    SELECT app_role_privilege_id INTO v_id 
    FROM app_role_privilege 
    WHERE role_id = p_role_id AND settings_id = p_settings_id;
    
    IF v_id IS NOT NULL THEN
        UPDATE app_role_privilege 
        SET app_privilege_value = p_privilege_value
        WHERE app_role_privilege_id = v_id;
    ELSE
        INSERT INTO app_role_privilege(role_id, settings_id, app_privilege_value, created_on)
        VALUES(p_role_id, p_settings_id, p_privilege_value, NOW());
    END IF;
    
    SELECT v_id AS app_role_privilege_id;
END ;;
DELIMITER ;
