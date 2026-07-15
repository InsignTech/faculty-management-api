DROP PROCEDURE IF EXISTS `sp_save_exceptional_day`;

DELIMITER ;;
CREATE PROCEDURE `sp_save_exceptional_day`(
    IN p_exceptional_id INT,
    IN p_holiday_date DATE,
    IN p_description VARCHAR(255),
    IN p_is_active TINYINT
)
BEGIN
    IF p_exceptional_id IS NULL OR p_exceptional_id = 0 THEN
        INSERT INTO exceptional_days (holiday_date, description, is_active)
        VALUES (p_holiday_date, p_description, p_is_active)
        ON DUPLICATE KEY UPDATE 
            description = VALUES(description),
            is_active = VALUES(is_active);
        SELECT LAST_INSERT_ID() AS exceptional_id;
    ELSE
        UPDATE exceptional_days SET
            holiday_date = p_holiday_date,
            description = p_description,
            is_active = p_is_active
        WHERE exceptional_id = p_exceptional_id;
        SELECT p_exceptional_id AS exceptional_id;
    END IF;
END ;;
DELIMITER ;
