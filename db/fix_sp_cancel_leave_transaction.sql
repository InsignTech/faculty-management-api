USE `staffdesk`;

DELIMITER //

DROP PROCEDURE IF EXISTS `sp_cancel_leave` //

CREATE PROCEDURE `sp_cancel_leave`(
    IN p_leave_request_id INT,
    IN p_cancelled_by      INT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_leave_type VARCHAR(50);
    DECLARE v_total_days DECIMAL(10,2);
    DECLARE v_status VARCHAR(20);
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;

    -- ─── Transaction Management ──────────────────────────────────────────────
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT employee_id, leave_type, total_days, status, start_date, end_date
    INTO v_emp_id, v_leave_type, v_total_days, v_status, v_start_date, v_end_date
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leave request not found';
    END IF;

    IF v_status = 'Cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leave request is already cancelled';
    END IF;

    UPDATE leave_requests
    SET status = 'Cancelled',
        approved_by_id = p_cancelled_by,
        approved_on = NOW()
    WHERE leave_request_id = p_leave_request_id;

    IF v_status = 'Approved' THEN
        UPDATE employee_leaves
        SET leaves_taken = leaves_taken - v_total_days
        WHERE emp_id = v_emp_id 
          AND leave_type = v_leave_type 
          AND month_year = DATE_FORMAT(NOW(), '%m-%Y');
        
        UPDATE attendance_daily
        SET is_leave = 0,
            is_leave_type = NULL,
            leave_shift_type = NULL,
            status = CASE 
                WHEN regularization_shift_type IS NOT NULL OR onduty_shift_type IS NOT NULL OR (shift_type IS NOT NULL AND shift_type != 'Absent') THEN 'Present'
                ELSE 'Absent'
            END
        WHERE employee_id = v_emp_id 
          AND date BETWEEN v_start_date AND v_end_date
          AND is_leave = 1;
    END IF;

    COMMIT;

    SELECT p_leave_request_id AS leave_request_id, 'Cancelled' AS status;
END //

DELIMITER ;
