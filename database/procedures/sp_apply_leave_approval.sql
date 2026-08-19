DROP PROCEDURE IF EXISTS `sp_apply_leave_approval`;

DELIMITER ;;
CREATE PROCEDURE `sp_apply_leave_approval`(
    IN p_leave_request_id INT
)
BEGIN
    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_status         VARCHAR(20);
    DECLARE v_current_date   DATE;

    SELECT
        employee_id,
        start_date,
        end_date,
        status
    INTO
        v_emp_id,
        v_start_date,
        v_end_date,
        v_status
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    IF v_status != 'Approved' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Leave request is not in Approved status';
    END IF;

    SET v_current_date = v_start_date;

    date_loop: WHILE v_current_date <= v_end_date DO
        -- Rebuild the attendance record using standard daily process (which incorporates leave requests)
        CALL sp_process_attendance_shiftwise(v_current_date);
        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE;

END ;;
DELIMITER ;
