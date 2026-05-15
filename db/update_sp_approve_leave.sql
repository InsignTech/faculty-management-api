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

    -- ── Phase 1: Validation Loop (Check for conflicts BEFORE updating balance) ──
    SET v_current_date = v_start_date;
    validation_loop: WHILE v_current_date <= v_end_date DO
        SET @is_reg = 0;
        SET @reg_shift = NULL;
        SET @is_leave = 0;
        SET @leave_shift = NULL;

        SELECT regularization_shift_type, is_leave, leave_shift_type 
        INTO @reg_shift, @is_leave, @leave_shift
        FROM   attendance_daily
        WHERE  employee_id = v_emp_id AND date = v_current_date
        FOR UPDATE;

        -- Check Regularization/On-Duty Conflict
        IF @reg_shift IS NOT NULL THEN
            IF @reg_shift = 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: One or more days are already fully regularized/on-duty';
            END IF;

            IF @reg_shift = v_leave_half AND v_leave_half != 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: This half of the day is already regularized/on-duty';
            END IF;
            
            IF v_leave_half = 'FullDay' AND @reg_shift != 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: A part of this day is already regularized/on-duty. Cannot apply full-day leave.';
            END IF;
        END IF;

        -- Check Leave Conflict
        IF @is_leave = 1 THEN
            IF @leave_shift = 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: One or more days already have an approved leave';
            END IF;

            IF @leave_shift = v_leave_half AND v_leave_half != 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: An approved leave already exists for this half-day';
            END IF;

            IF v_leave_half = 'FullDay' AND @leave_shift != 'FullDay' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: A part of this day already has an approved leave. Cannot apply full-day leave.';
            END IF;
        END IF;

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE;

    -- ── Phase 2: Update employee_leaves table (Safe now because Phase 1 passed) ──
    IF p_action = 'Approved' THEN
        SET @v_total_days = 0;
        SELECT total_days INTO @v_total_days FROM leave_requests WHERE leave_request_id = p_leave_request_id;
        
        INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
        VALUES (v_emp_id, v_leave_type, DATE_FORMAT(NOW(), '%m-%Y'), 0, 0, @v_total_days)
        ON DUPLICATE KEY UPDATE 
            leaves_taken = leaves_taken + @v_total_days;
    END IF;

    -- ── If rejected, nothing more to do ─────────────────────────────────────
    IF p_action = 'Rejected' THEN
        SELECT
            p_leave_request_id AS leave_request_id,
            'Rejected'         AS status;
        LEAVE proc;
    END IF;

    -- ── Phase 3: Update attendance_daily ─────────────────────────────────────
    SET v_current_date = v_start_date;
    date_loop: WHILE v_current_date <= v_end_date DO
        -- Read existing data for merge logic
        SET @is_reg = 0;
        SET @reg_shift = NULL;
        SET @cur_shift = NULL;

        SELECT regularization_shift_type, onduty_shift_type, shift_type
        INTO @reg_shift, @onduty_shift, @cur_shift
        FROM   attendance_daily
        WHERE  employee_id = v_emp_id AND date = v_current_date
        LIMIT  1;

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
                regularization_shift_type,
                is_leave, is_leave_type, leave_shift_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                @final_shift, @final_status,
                0, 0, 0, 0, 0, 0,
                0, NULL,
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
                regularization_shift_type = NULL,
                is_leave           = 1,
                is_leave_type      = v_leave_type,
                leave_shift_type   = v_leave_half;

        -- ─────────────────────────────────────────────────────────────────────
        -- ── First half leave ──────────────────────────────────────────────────
        -- ─────────────────────────────────────────────────────────────────────
        ELSEIF v_leave_half = 'FirstHalf' THEN

            -- Logic: If second half is covered by Physical Punch OR Regularization OR On-Duty OR existing Leave
            SET @is_second_covered = IF(
                @cur_shift IN ('SecondHalf','FullDay') OR 
                @reg_shift IN ('SecondHalf','FullDay') OR 
                @onduty_shift IN ('SecondHalf','FullDay') OR
                (@is_leave = 1 AND @leave_shift IN ('SecondHalf','FullDay')), 
                1, 0
            );
            
            SET @final_shift  = IF(@is_second_covered = 1, 'FullDay', 'FirstHalf');
            SET @final_status = IF(@is_second_covered = 1, 'Present', 'Leave');
            SET @final_deduct = IF(@is_second_covered = 1, 0.00, 0.50);

            INSERT INTO attendance_daily (
                employee_id, date,
                first_in_time, last_out_time, worked_mins,
                shift_type, status,
                is_late, late_minutes,
                is_early_leaving, early_minutes,
                overtime_minutes, deduction_days,
                is_worked_on_holiday,
                regularization_shift_type, onduty_shift_type,
                is_leave, is_leave_type, leave_shift_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                @final_shift, @final_status,
                0, 0, 0, 0, 0,
                @final_deduct,
                0, @reg_shift, @onduty_shift,
                1, v_leave_type, v_leave_half
            )
            ON DUPLICATE KEY UPDATE
                shift_type         = @final_shift,
                status             = @final_status,
                deduction_days     = @final_deduct,
                is_leave           = 1,
                is_leave_type      = v_leave_type,
                leave_shift_type   = v_leave_half;

        -- ─────────────────────────────────────────────────────────────────────
        -- ── Second half leave ─────────────────────────────────────────────────
        -- ─────────────────────────────────────────────────────────────────────
        ELSEIF v_leave_half = 'SecondHalf' THEN

            -- Logic: If first half is covered by Physical Punch OR Regularization OR On-Duty OR existing Leave
            SET @is_first_covered = IF(
                @cur_shift IN ('FirstHalf','FullDay') OR 
                @reg_shift IN ('FirstHalf','FullDay') OR 
                @onduty_shift IN ('FirstHalf','FullDay') OR
                (@is_leave = 1 AND @leave_shift IN ('FirstHalf','FullDay')), 
                1, 0
            );

            SET @final_shift  = IF(@is_first_covered = 1, 'FullDay', 'SecondHalf');
            SET @final_status = IF(@is_first_covered = 1, 'Present', 'Leave');
            SET @final_deduct = IF(@is_first_covered = 1, 0.00, 0.50);

            INSERT INTO attendance_daily (
                employee_id, date,
                first_in_time, last_out_time, worked_mins,
                shift_type, status,
                is_late, late_minutes,
                is_early_leaving, early_minutes,
                overtime_minutes, deduction_days,
                is_worked_on_holiday,
                regularization_shift_type, onduty_shift_type,
                is_leave, is_leave_type, leave_shift_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                @final_shift, @final_status,
                0, 0, 0, 0, 0,
                @final_deduct,
                0, @reg_shift, @onduty_shift,
                1, v_leave_type, v_leave_half
            )
            ON DUPLICATE KEY UPDATE
                shift_type         = @final_shift,
                status             = @final_status,
                deduction_days     = @final_deduct,
                is_leave           = 1,
                is_leave_type      = v_leave_type,
                leave_shift_type   = v_leave_half;
        END IF;

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

-- ─── Also Fix sp_apply_leave to match the new schema and controller parameters ───
DROP PROCEDURE IF EXISTS `sp_apply_leave` //
CREATE PROCEDURE `sp_apply_leave`(
    IN p_employee_id  INT,
    IN p_leave_type   VARCHAR(50),
    IN p_start_date   DATE,
    IN p_end_date     DATE,
    IN p_half_type    VARCHAR(20),  -- 'FullDay', 'FirstHalf', 'SecondHalf'
    IN p_reason       TEXT,
    IN p_attachment   VARCHAR(512)
)
BEGIN
    DECLARE v_total_days DECIMAL(5,2) DEFAULT 0;
    DECLARE v_current_date DATE;
    DECLARE v_skip TINYINT DEFAULT 0;

    -- Validate date range
    IF p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Start date cannot be after end date';
    END IF;

    -- Half day must be a single day
    IF p_half_type != 'FullDay' AND p_start_date != p_end_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Half day leave must be on a single date';
    END IF;

    -- Loop through each day, exclude Sundays and holidays
    SET v_current_date = p_start_date;
    WHILE v_current_date <= p_end_date DO
        SET v_skip = 0;

        -- Skip Sundays
        IF DAYNAME(v_current_date) = 'Sunday' THEN
            SET v_skip = 1;
        END IF;

        -- Skip holidays
        IF v_skip = 0 AND EXISTS (
            SELECT 1 FROM holiday_master
            WHERE (v_current_date BETWEEN holiday_start_date AND holiday_end_date)
              AND is_active = 1
              AND (employee_id = -1 OR employee_id = p_employee_id)
              AND holiday_type != 'WeekEnd'
        ) THEN
            SET v_skip = 1;
        END IF;

        IF v_skip = 0 THEN
            IF p_half_type = 'FullDay' THEN
                SET v_total_days = v_total_days + 1;
            ELSE
                SET v_total_days = v_total_days + 0.5;
            END IF;
        END IF;

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE;

    INSERT INTO leave_requests (
        employee_id, leave_type, start_date, end_date, leave_half_type,
        total_days, reason, attachment_path, status, applied_on
    ) VALUES (
        p_employee_id, p_leave_type, p_start_date, p_end_date, p_half_type,
        v_total_days, p_reason, p_attachment, 'Pending', NOW()
    );

    SELECT LAST_INSERT_ID() AS leave_request_id, v_total_days AS total_days, 'Pending' AS status;
END //

DELIMITER ;
