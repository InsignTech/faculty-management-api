DROP PROCEDURE IF EXISTS `sp_get_exceptional_days`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_exceptional_days`(
    IN p_year INT
)
BEGIN
    SELECT * FROM exceptional_days
    WHERE (p_year IS NULL OR YEAR(holiday_date) = p_year)
    ORDER BY holiday_date ASC;
END ;;
DELIMITER ;
