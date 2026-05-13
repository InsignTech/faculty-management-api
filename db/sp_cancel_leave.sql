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

    -- 1. Get request details
    SELECT employee_id, leave_type, total_days, status, start_date, end_date
    INTO v_emp_id, v_leave_type, v_total_days, v_status, v_start_date, v_end_date
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    -- 2. Update status
    UPDATE leave_requests
    SET status = 'Cancelled',
        approved_by_id = p_cancelled_by,
        approved_on = NOW()
    WHERE leave_request_id = p_leave_request_id;

    -- 3. If it was approved, reverse the leaves_taken in employee_leaves
    IF v_status = 'Approved' THEN
        UPDATE employee_leaves
        SET leaves_taken = leaves_taken - v_total_days
        WHERE emp_id = v_emp_id 
          AND leave_type = v_leave_type 
          AND month_year = DATE_FORMAT(NOW(), '%m-%Y');
        
        -- Also need to reverse attendance_daily status
        UPDATE attendance_daily
        SET status = 'Absent', 
            is_leave = 0,
            is_leave_type = NULL,
            leave_shift_type = NULL
        WHERE employee_id = v_emp_id 
          AND date BETWEEN v_start_date AND v_end_date
          AND is_leave = 1;
    END IF;

    SELECT p_leave_request_id AS leave_request_id, 'Cancelled' AS status;
END //

DELIMITER ;
