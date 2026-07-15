DROP PROCEDURE IF EXISTS `sp_get_setting`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_setting`(
    IN p_setting_key VARCHAR(100)
)
BEGIN
    SELECT settings_key, settings_value 
    FROM settings 
    WHERE settings_key = p_setting_key;
END ;;
DELIMITER ;
