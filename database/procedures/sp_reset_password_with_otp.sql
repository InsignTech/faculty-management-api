DROP PROCEDURE IF EXISTS `sp_reset_password_with_otp`;

DELIMITER ;;
CREATE PROCEDURE `sp_reset_password_with_otp`(
    IN p_email VARCHAR(255),
    IN p_otp INT,
    IN p_new_password VARCHAR(5000)
)
BEGIN
    
    UPDATE user_accounts 
    SET user_password = p_new_password,
        otp = NULL,
        otp_generated_on = NULL
    WHERE email = p_email 
      AND otp = p_otp 
      AND otp_generated_on >= DATE_SUB(NOW(), INTERVAL 15 MINUTE);
    
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
