-- Stored Procedures for User Authentication and Password Reset
USE `staffdesk`;

DELIMITER //

-- Get user details for login
DROP PROCEDURE IF EXISTS `sp_get_user_auth_details` //
CREATE PROCEDURE `sp_get_user_auth_details`(
    IN p_email VARCHAR(255)
)
BEGIN
    SELECT 
        ua.user_accounts_id, 
        ua.user_display_name, 
        ua.user_password, 
        ua.email, 
        ua.role_id, 
        ua.employee_id, 
        ua.active,
        r.role AS role_name
    FROM user_accounts ua
    LEFT JOIN app_role r ON ua.role_id = r.role_id
    WHERE ua.email = p_email AND ua.active = 1;
END //

-- Update user OTP
DROP PROCEDURE IF EXISTS `sp_update_user_otp` //
CREATE PROCEDURE `sp_update_user_otp`(
    IN p_email VARCHAR(255),
    IN p_otp INT
)
BEGIN
    UPDATE user_accounts 
    SET otp = p_otp, 
        otp_generated_on = NOW()
    WHERE email = p_email;
    
    SELECT ROW_COUNT() AS affected_rows;
END //

-- Reset password with old password
DROP PROCEDURE IF EXISTS `sp_reset_password_with_old` //
CREATE PROCEDURE `sp_reset_password_with_old`(
    IN p_user_id INT,
    IN p_new_password VARCHAR(5000)
)
BEGIN
    UPDATE user_accounts 
    SET user_password = p_new_password,
        otp = NULL,
        otp_generated_on = NULL
    WHERE user_accounts_id = p_user_id;
    
    SELECT ROW_COUNT() AS affected_rows;
END //

-- Reset password with OTP
DROP PROCEDURE IF EXISTS `sp_reset_password_with_otp` //
CREATE PROCEDURE `sp_reset_password_with_otp`(
    IN p_email VARCHAR(255),
    IN p_otp INT,
    IN p_new_password VARCHAR(5000)
)
BEGIN
    -- Only update if OTP matches and is within 15 minutes
    UPDATE user_accounts 
    SET user_password = p_new_password,
        otp = NULL,
        otp_generated_on = NULL
    WHERE email = p_email 
      AND otp = p_otp 
      AND otp_generated_on >= DATE_SUB(NOW(), INTERVAL 15 MINUTE);
    
    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;
