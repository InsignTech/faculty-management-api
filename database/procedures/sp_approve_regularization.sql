DROP PROCEDURE IF EXISTS `sp_approve_regularization`;

DELIMITER ;;
CREATE PROCEDURE `sp_approve_regularization`(
    IN p_reg_id      INT,
    IN p_approved_by INT
)
BEGIN
    
    UPDATE attendance_regularization
    SET    status      = 'Approved',
           approved_by = p_approved_by,
           approved_on = NOW()
    WHERE  id     = p_reg_id
      AND  status = 'Pending';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Request not found or already processed';
    END IF;

    
    CALL sp_apply_regularization(p_reg_id, p_approved_by);
END ;;
DELIMITER ;
