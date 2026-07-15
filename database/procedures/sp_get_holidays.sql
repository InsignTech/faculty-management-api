DROP PROCEDURE IF EXISTS `sp_get_holidays`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_holidays`(
    IN p_year INT
)
BEGIN
    SELECT * FROM holidays
    WHERE (p_year IS NULL OR YEAR(holiday_date) = p_year)
    ORDER BY holiday_date ASC;
END ;;
DELIMITER ;
