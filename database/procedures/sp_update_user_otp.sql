DROP PROCEDURE IF EXISTS `sp_update_user_otp`;

DELIMITER ;;
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
END ;;
DELIMITER ;
