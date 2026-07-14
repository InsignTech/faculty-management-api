DROP PROCEDURE IF EXISTS `sp_delete_holiday`;

DELIMITER ;;
CREATE PROCEDURE `sp_delete_holiday`(IN p_holiday_id INT)
BEGIN
    DELETE FROM holidays WHERE holiday_id = p_holiday_id;
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
