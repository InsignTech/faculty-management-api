DROP PROCEDURE IF EXISTS `sp_reset_password_with_old`;

DELIMITER ;;
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
END ;;
DELIMITER ;
