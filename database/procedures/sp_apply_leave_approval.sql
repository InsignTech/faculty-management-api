DROP PROCEDURE IF EXISTS `sp_apply_leave_approval`;

DELIMITER ;;
CREATE PROCEDURE `sp_apply_leave_approval`(
    IN p_leave_request_id INT
)
BEGIN

    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_leave_type     VARCHAR(50);
    DECLARE v_leave_half     ENUM('FullDay','FirstHalf','SecondHalf');
    DECLARE v_total_days     DECIMAL(5,2);
    DECLARE v_status         VARCHAR(20);

    DECLARE v_current_date   DATE;

    
    SELECT
        employee_id,
        start_date,
        end_date,
        leave_type,
        COALESCE(leave_half, 'FullDay'),
        total_days,
        status
    INTO
        v_emp_id,
        v_start_date,
        v_end_date,
        v_leave_type,
        v_leave_half,
        v_total_days,
        v_status
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    
    IF v_status != 'Approved' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Leave request is not in Approved status';
    END IF;

    SET v_current_date = v_start_date;

    date_loop: WHILE v_current_date <= v_end_date DO

        
        IF EXISTS (
            SELECT 1 
            FROM holiday_master
            WHERE v_current_date BETWEEN holiday_start_date AND holiday_end_date
              AND is_active = 1
        ) THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        
        IF v_leave_half = 'FullDay' THEN

            INSERT INTO attendance_daily (
                employee_id, date,
                shift_type, status,
                deduction_days
            )
            VALUES (
                v_emp_id, v_current_date,
                'Absent',
                'Leave',
                0
            )
            ON DUPLICATE KEY UPDATE
                shift_type = 'Absent',
                status = 'Leave',
                deduction_days = 0;

        
        ELSEIF v_leave_half = 'FirstHalf' THEN

            INSERT INTO attendance_daily (
                employee_id, date,
                shift_type, status,
                deduction_days
            )
            VALUES (
                v_emp_id, v_current_date,
                'FirstHalf',
                'Leave',
                0.5   
            )
            ON DUPLICATE KEY UPDATE
                shift_type = 'FirstHalf',
                status = 'Leave',
                deduction_days = 0.5;

        
        ELSEIF v_leave_half = 'SecondHalf' THEN

            INSERT INTO attendance_daily (
                employee_id, date,
                shift_type, status,
                deduction_days
            )
            VALUES (
                v_emp_id, v_current_date,
                'SecondHalf',
                'Leave',
                0.5   
            )
            ON DUPLICATE KEY UPDATE
                shift_type = 'SecondHalf',
                status = 'Leave',
                deduction_days = 0.5;

        END IF;

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);

    END WHILE;

END ;;
DELIMITER ;
