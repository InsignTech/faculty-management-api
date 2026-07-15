DROP PROCEDURE IF EXISTS `sp_get_attendance_settings`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_attendance_settings`()
BEGIN
    SELECT * FROM attendance_settings ORDER BY setting_key;
END ;;
DELIMITER ;
