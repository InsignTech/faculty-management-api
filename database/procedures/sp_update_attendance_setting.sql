DROP PROCEDURE IF EXISTS `sp_update_attendance_setting`;

DELIMITER ;;
CREATE PROCEDURE `sp_update_attendance_setting`(
    IN p_key VARCHAR(100),
    IN p_value VARCHAR(255)
)
BEGIN
    UPDATE attendance_settings SET setting_value = p_value WHERE setting_key = p_key;
    SELECT ROW_COUNT() AS updated;
END ;;
DELIMITER ;
