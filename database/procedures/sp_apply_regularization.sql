DROP PROCEDURE IF EXISTS `sp_apply_regularization`;

DELIMITER ;;
CREATE PROCEDURE `sp_apply_regularization`(
    IN p_reg_id     INT,   
    IN p_approved_by INT   
)
BEGIN
    DECLARE v_emp_id   INT;
    DECLARE v_date     DATE;
    DECLARE v_status   VARCHAR(20);

    SELECT employee_id, date, status
    INTO   v_emp_id, v_date, v_status
    FROM   attendance_regularization
    WHERE  id = p_reg_id;

    IF v_status != 'Approved' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regularization request is not in Approved status';
    END IF;

    -- Update the regularization request details
    UPDATE attendance_regularization
    SET    status      = 'Approved',
           approved_by = p_approved_by,
           approved_on = NOW()
    WHERE  id = p_reg_id;

    -- Rebuild the attendance record(s) using the daily process (which incorporates regularizations)
    CALL sp_process_attendance_shiftwise(v_date);

END ;;
DELIMITER ;
