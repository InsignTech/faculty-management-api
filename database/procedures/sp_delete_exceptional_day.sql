DROP PROCEDURE IF EXISTS `sp_delete_exceptional_day`;

DELIMITER ;;
CREATE PROCEDURE `sp_delete_exceptional_day`(IN p_exceptional_id INT)
BEGIN
    DELETE FROM exceptional_days WHERE exceptional_id = p_exceptional_id;
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
