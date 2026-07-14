DROP PROCEDURE IF EXISTS `sp_save_holiday`;

DELIMITER ;;
CREATE PROCEDURE `sp_save_holiday`(
    IN p_holiday_id INT,
    IN p_holiday_date DATE,
    IN p_description VARCHAR(255),
    IN p_is_active TINYINT
)
BEGIN
    IF p_holiday_id IS NULL OR p_holiday_id = 0 THEN
        INSERT INTO holidays (holiday_date, description, is_active)
        VALUES (p_holiday_date, p_description, p_is_active)
        ON DUPLICATE KEY UPDATE description = p_description, is_active = p_is_active;
        SELECT LAST_INSERT_ID() AS holiday_id;
    ELSE
        UPDATE holidays SET
            holiday_date = p_holiday_date,
            description = p_description,
            is_active = p_is_active
        WHERE holiday_id = p_holiday_id;
        SELECT p_holiday_id AS holiday_id;
    END IF;
END ;;
DELIMITER ;
