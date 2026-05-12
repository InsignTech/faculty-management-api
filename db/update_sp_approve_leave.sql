USE `staffdesk`;

DELIMITER //

DROP PROCEDURE IF EXISTS `sp_approve_leave` //

CREATE PROCEDURE `sp_approve_leave`(
    IN p_leave_request_id INT,
    IN p_approved_by      INT,
    IN p_action           ENUM('Approved','Rejected'),
    IN p_rejection_reason TEXT
)
proc: BEGIN

    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_leave_type     VARCHAR(50);
    DECLARE v_leave_half     VARCHAR(20);
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_current_date   DATE;

    -- ─── Load and validate the request ───────────────────────────────────────
    SELECT
        employee_id,
        start_date,
        end_date,
        leave_type,
        COALESCE(leave_half_type, 'FullDay'),
        status
    INTO
        v_emp_id,
        v_start_date,
        v_end_date,
        v_leave_type,
        v_leave_half,
        v_current_status
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Leave request not found';
    END IF;

    IF v_current_status != 'Pending' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only Pending requests can be approved or rejected';
    END IF;

    IF p_action = 'Rejected' AND (p_rejection_reason IS NULL OR TRIM(p_rejection_reason) = '') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rejection reason is required when rejecting a leave request';
    END IF;

    -- ─── Update leave request status ─────────────────────────────────────────
    UPDATE leave_requests
    SET
        status           = p_action,
        approved_by_id   = p_approved_by,
        approved_on      = NOW(),
        rejection_reason = IF(p_action = 'Rejected', p_rejection_reason, NULL)
    WHERE leave_request_id = p_leave_request_id;

    -- ─── If rejected, nothing more to do ─────────────────────────────────────
    IF p_action = 'Rejected' THEN
        SELECT
            p_leave_request_id AS leave_request_id,
            'Rejected'         AS status;
        LEAVE proc;
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- ─── Approved: update attendance_daily for every day in the range ────────
    -- ─────────────────────────────────────────────────────────────────────────
    SET v_current_date = v_start_date;

    date_loop: WHILE v_current_date <= v_end_date DO

        -- ── Skip already regularized days ────────────────────────────────────
        SET @is_regularized = 0;

        SELECT is_regularized INTO @is_regularized
        FROM   attendance_daily
        WHERE  employee_id = v_emp_id
          AND  date        = v_current_date
        LIMIT  1;

        IF @is_regularized = 1 THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        -- ── Skip weekends and holidays ────────────────────────────────────────
        SET @holiday_type    = NULL;
        SET @existing_status = NULL;

        SELECT status INTO @existing_status
        FROM   attendance_daily
        WHERE  employee_id = v_emp_id
          AND  date        = v_current_date
        LIMIT  1;

        IF @existing_status IN ('WeekEnd','Public Holiday','Exceptional Holiday') THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        SELECT holiday_type INTO @holiday_type
        FROM   holiday_master
        WHERE  v_current_date BETWEEN holiday_start_date AND holiday_end_date
          AND  is_active   = 1
          AND  employee_id IN (v_emp_id, -1)
        ORDER BY CASE WHEN employee_id = -1 THEN 1 ELSE 2 END
        LIMIT 1;

        IF @holiday_type IS NOT NULL THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        -- ── Read existing punch data ──────────────────────────────────────────
        SET @first_in    = NULL;
        SET @last_out    = NULL;
        SET @worked_mins = 0;
        SET @cur_shift   = NULL;
        SET @cur_deduct  = 0;

        SELECT
            first_in_time,
            last_out_time,
            worked_mins,
            shift_type,
            deduction_days
        INTO
            @first_in,
            @last_out,
            @worked_mins,
            @cur_shift,
            @cur_deduct
        FROM attendance_daily
        WHERE employee_id = v_emp_id
          AND date        = v_current_date
        LIMIT 1;

        -- ─────────────────────────────────────────────────────────────────────
        -- ── Full day leave ────────────────────────────────────────────────────
        -- ─────────────────────────────────────────────────────────────────────
        IF v_leave_half = 'FullDay' THEN

            -- If employee actually punched in, reflect real shift
            SET @final_shift  = IF(@cur_shift IS NOT NULL AND @cur_shift != 'Absent',
                                   @cur_shift, 'Absent');
            SET @final_status = IF(@cur_shift IS NOT NULL AND @cur_shift != 'Absent',
                                   'Present', 'Leave');

            INSERT INTO attendance_daily (
                employee_id, date,
                first_in_time, last_out_time, worked_mins,
                shift_type, status,
                is_late, late_minutes,
                is_early_leaving, early_minutes,
                overtime_minutes, deduction_days,
                is_worked_on_holiday,
                is_regularized, is_regularize_type,
                is_leave, is_leave_type, leave_shift_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                @final_shift, @final_status,
                0, 0, 0, 0, 0, 0,
                0, 0, NULL,
                1, v_leave_type, v_leave_half
            )
            ON DUPLICATE KEY UPDATE
                shift_type         = @final_shift,
                status             = @final_status,
                is_late            = 0,
                late_minutes       = 0,
                is_early_leaving   = 0,
                early_minutes      = 0,
                overtime_minutes   = 0,
                deduction_days     = 0,
                is_regularized     = 0,
                is_regularize_type = NULL,
                is_leave           = 1,
                is_leave_type      = v_leave_type,
                leave_shift_type   = v_leave_half;

        -- ─────────────────────────────────────────────────────────────────────
        -- ── First half leave ──────────────────────────────────────────────────
        -- ─────────────────────────────────────────────────────────────────────
        ELSEIF v_leave_half = 'FirstHalf' THEN

            -- If second half also worked → FullDay Present, 0 deduction
            -- If second half not worked  → FirstHalf Leave, 0.5 deduction
            SET @final_shift  = IF(@cur_shift IN ('SecondHalf','FullDay'),
                                   'FullDay', 'FirstHalf');
            SET @final_status = IF(@cur_shift IN ('SecondHalf','FullDay'),
                                   'Present', 'Leave');
            SET @final_deduct = IF(@cur_shift IN ('SecondHalf','FullDay'),
                                   0, 0.5);

            INSERT INTO attendance_daily (
                employee_id, date,
                first_in_time, last_out_time, worked_mins,
                shift_type, status,
                is_late, late_minutes,
                is_early_leaving, early_minutes,
                overtime_minutes, deduction_days,
                is_worked_on_holiday,
                is_regularized, is_regularize_type,
                is_leave, is_leave_type, leave_shift_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                @final_shift, @final_status,
                0, 0, 0, 0, 0,
                @final_deduct,
                0, 0, NULL,
                1, v_leave_type, v_leave_half
            )
            ON DUPLICATE KEY UPDATE
                shift_type         = @final_shift,
                status             = @final_status,
                is_late            = 0,
                late_minutes       = 0,
                is_early_leaving   = 0,
                early_minutes      = 0,
                deduction_days     = @final_deduct,
                is_regularized     = 0,
                is_regularize_type = NULL,
                is_leave           = 1,
                is_leave_type      = v_leave_type,
                leave_shift_type   = v_leave_half;

        -- ─────────────────────────────────────────────────────────────────────
        -- ── Second half leave ─────────────────────────────────────────────────
        -- ─────────────────────────────────────────────────────────────────────
        ELSEIF v_leave_half = 'SecondHalf' THEN

            -- If first half also worked → FullDay Present, 0 deduction
            -- If first half not worked  → SecondHalf Leave, 0.5 deduction
            SET @final_shift  = IF(@cur_shift IN ('FirstHalf','FullDay'),
                                   'FullDay', 'SecondHalf');
            SET @final_status = IF(@cur_shift IN ('FirstHalf','FullDay'),
                                   'Present', 'Leave');
            SET @final_deduct = IF(@cur_shift IN ('FirstHalf','FullDay'),
                                   0, 0.5);

            INSERT INTO attendance_daily (
                employee_id, date,
                first_in_time, last_out_time, worked_mins,
                shift_type, status,
                is_late, late_minutes,
                is_early_leaving, early_minutes,
                overtime_minutes, deduction_days,
                is_worked_on_holiday,
                is_regularized, is_regularize_type,
                is_leave, is_leave_type, leave_shift_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                @final_shift, @final_status,
                0, 0, 0, 0, 0,
                @final_deduct,
                0, 0, NULL,
                1, v_leave_type, v_leave_half
            )
            ON DUPLICATE KEY UPDATE
                shift_type         = @final_shift,
                status             = @final_status,
                is_late            = 0,
                late_minutes       = 0,
                is_early_leaving   = 0,
                early_minutes      = 0,
                deduction_days     = @final_deduct,
                is_regularized     = 0,
                is_regularize_type = NULL,
                is_leave           = 1,
                is_leave_type      = v_leave_type,
                leave_shift_type   = v_leave_half;

        END IF;

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);

    END WHILE date_loop;

    -- ─── Return summary ───────────────────────────────────────────────────────
    SELECT
        p_leave_request_id                          AS leave_request_id,
        v_emp_id                                    AS employee_id,
        v_start_date                                AS start_date,
        v_end_date                                  AS end_date,
        v_leave_half                                AS leave_half_type,
        'Approved'                                  AS status,
        DATEDIFF(v_end_date, v_start_date) + 1      AS calendar_days,
        (SELECT total_days FROM leave_requests
         WHERE leave_request_id = p_leave_request_id) AS working_days_deducted;

END //

DELIMITER ;
