-- Update Stored Procedure for Settings
DROP PROCEDURE IF EXISTS sp_get_setting;
DELIMITER //
CREATE PROCEDURE sp_get_setting(
    IN p_settings_key VARCHAR(150)
)
BEGIN
    SELECT settings_key, settings_value 
    FROM settings 
    WHERE settings_key = p_settings_key;
END //
DELIMITER ;

-- Seed Regularization Limit
INSERT IGNORE INTO settings (settings_key, settings_value, created_by)
VALUES ('regularization_limit', '3', 'SYSTEM');
