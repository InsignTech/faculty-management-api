DROP PROCEDURE IF EXISTS `sp_save_role_privilage`;

DELIMITER ;;
CREATE PROCEDURE `sp_save_role_privilage`(
    IN p_role_id INT,
    IN p_settings_id INT,
    IN p_privilage_value JSON
)
BEGIN
    DECLARE v_id INT;
    
    SELECT role_privilage_id INTO v_id 
    FROM app_role_privilage 
    WHERE role_id = p_role_id AND settings_id = p_settings_id;
    
    IF v_id IS NOT NULL THEN
        UPDATE app_role_privilage 
        SET privilage_value = p_privilage_value
        WHERE role_privilage_id = v_id;
    ELSE
        INSERT INTO app_role_privilage(role_id, settings_id, privilage_value)
        VALUES(p_role_id, p_settings_id, p_privilage_value);
    END IF;
    
    SELECT v_id AS role_privilage_id;
END ;;
DELIMITER ;
