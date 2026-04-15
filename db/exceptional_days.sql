USE `staffdesk`;

-- Corrected Table for Exceptional Days (Restricted/Optional Holidays)
-- This is a GLOBAL list managed by Admin
DROP TABLE IF EXISTS `exceptional_days`;
CREATE TABLE IF NOT EXISTS `exceptional_days` (
    `exceptional_id` INT NOT NULL AUTO_INCREMENT,
    `holiday_date` DATE NOT NULL,
    `description` VARCHAR(255) NOT NULL,
    `is_active` TINYINT DEFAULT 1,
    `added_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`exceptional_id`),
    UNIQUE KEY `idx_date_exceptional` (`holiday_date`)
);

DELIMITER //

-- Get Global Exceptional Days
DROP PROCEDURE IF EXISTS `sp_get_exceptional_days` //
CREATE PROCEDURE `sp_get_exceptional_days`(
    IN p_year INT
)
BEGIN
    SELECT * FROM exceptional_days
    WHERE (p_year IS NULL OR YEAR(holiday_date) = p_year)
    ORDER BY holiday_date ASC;
END //

-- Save or Update Global Exceptional Day
DROP PROCEDURE IF EXISTS `sp_save_exceptional_day` //
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
END //

-- Delete Global Exceptional Day
DROP PROCEDURE IF EXISTS `sp_delete_exceptional_day` //
CREATE PROCEDURE `sp_delete_exceptional_day`(IN p_exceptional_id INT)
BEGIN
    DELETE FROM exceptional_days WHERE exceptional_id = p_exceptional_id;
    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;
