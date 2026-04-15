-- Settings Table
CREATE TABLE IF NOT EXISTS settings (
    setting_id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    description TEXT,
    modified_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Stored Procedure: Get Setting By Key
DROP PROCEDURE IF EXISTS sp_get_setting;
DELIMITER //
CREATE PROCEDURE sp_get_setting(
    IN p_setting_key VARCHAR(100)
)
BEGIN
    SELECT setting_key, setting_value 
    FROM settings 
    WHERE setting_key = p_setting_key;
END //
DELIMITER ;

-- Insert Default Regularization Limit
INSERT IGNORE INTO settings (setting_key, setting_value, description)
VALUES ('regularization_limit', '3', 'Maximum free regularization requests allowed per month');
