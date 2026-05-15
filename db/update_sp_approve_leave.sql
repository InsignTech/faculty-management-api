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

    -- ─── Transaction Management ──────────────────────────────────────────────
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

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
    IF p_action = 'Approved' THEN
        SET v_current_date = v_start_date;
        validation_loop: WHILE v_current_date <= v_end_date DO
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
        SET @v_total_days = 0;
        SELECT total_days INTO @v_total_days FROM leave_requests WHERE leave_request_id = p_leave_request_id;
        
        INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
        VALUES (v_emp_id, v_leave_type, DATE_FORMAT(NOW(), '%m-%Y'), 0, 0, @v_total_days)
        ON DUPLICATE KEY UPDATE 
            leaves_taken = leaves_taken + @v_total_days;

        -- ── Phase 3: Update attendance_daily ─────────────────────────────────────
        SET v_current_date = v_start_date;
        date_loop: WHILE v_current_date <= v_end_date DO
            -- ── Skip weekends and holidays ────────────────────────────────────────
            SET @existing_status = NULL;
            SELECT status INTO @existing_status FROM attendance_daily
            WHERE employee_id = v_emp_id AND date = v_current_date LIMIT 1;

            IF @existing_status IN ('WeekEnd','Public Holiday','Exceptional Holiday') THEN
                SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
                ITERATE date_loop;
            END IF;

            IF EXISTS (
                SELECT 1 FROM holiday_master
                WHERE v_current_date BETWEEN holiday_start_date AND holiday_end_date
                  AND is_active = 1 AND employee_id IN (v_emp_id, -1)
            ) THEN
                SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
                ITERATE date_loop;
            END IF;

            -- Read ALL existing coverage data
            SET @first_in = NULL; SET @last_out = NULL; SET @worked_mins = 0;
            SET @cur_shift = NULL; SET @cur_status = NULL;
            SET @reg_shift = NULL; SET @od_shift = NULL;
            SET @is_leave_existing = 0; SET @leave_shift_existing = NULL;

            SELECT 
                first_in_time, last_out_time, worked_mins, 
                shift_type, status,
                regularization_shift_type, onduty_shift_type,
                is_leave, leave_shift_type
            INTO 
                @first_in, @last_out, @worked_mins,
                @cur_shift, @cur_status,
                @reg_shift, @od_shift,
                @is_leave_existing, @leave_shift_existing
            FROM attendance_daily
            WHERE employee_id = v_emp_id AND date = v_current_date
            LIMIT 1;

            -- ── Calculate Merged Coverage ────────────────────────────────────────
            SET @v_first_half_covered = (
                (@cur_shift IN ('FirstHalf', 'FullDay')) OR
                (@reg_shift IN ('FirstHalf', 'FullDay')) OR
                (@od_shift IN ('FirstHalf', 'FullDay')) OR
                (@is_leave_existing = 1 AND @leave_shift_existing IN ('FirstHalf', 'FullDay')) OR
                (v_leave_half IN ('FirstHalf', 'FullDay'))
            );

            SET @v_second_half_covered = (
                (@cur_shift IN ('SecondHalf', 'FullDay')) OR
                (@reg_shift IN ('SecondHalf', 'FullDay')) OR
                (@od_shift IN ('SecondHalf', 'FullDay')) OR
                (@is_leave_existing = 1 AND @leave_shift_existing IN ('SecondHalf', 'FullDay')) OR
                (v_leave_half IN ('SecondHalf', 'FullDay'))
            );

            SET @final_deduct = IF(@v_first_half_covered AND @v_second_half_covered, 0.00, 0.50);
            IF NOT @v_first_half_covered AND NOT @v_second_half_covered THEN SET @final_deduct = 1.00; END IF;

            SET @final_shift = 'Absent';
            IF @v_first_half_covered AND @v_second_half_covered THEN SET @final_shift = 'FullDay';
            ELSEIF @v_first_half_covered THEN SET @final_shift = 'FirstHalf';
            ELSEIF @v_second_half_covered THEN SET @final_shift = 'SecondHalf';
            END IF;

            SET @final_status = IF(@final_shift = 'FullDay' OR @cur_shift = 'FullDay', 'Present', 'Leave');

            -- Final Update
            INSERT INTO attendance_daily (
                employee_id, date, first_in_time, last_out_time, worked_mins,
                shift_type, status, is_late, late_minutes, is_early_leaving, early_minutes,
                overtime_minutes, deduction_days, is_worked_on_holiday,
                is_leave, is_leave_type, leave_shift_type
            ) VALUES (
                v_emp_id, v_current_date, @first_in, @last_out, @worked_mins,
                @final_shift, @final_status, 0, 0, 0, 0, 0,
                @final_deduct, 0, 1, v_leave_type, v_leave_half
            )
            ON DUPLICATE KEY UPDATE
                shift_type = @final_shift,
                status = @final_status,
                deduction_days = @final_deduct,
                is_leave = 1,
                is_leave_type = v_leave_type,
                leave_shift_type = IF(v_leave_half = 'FullDay', 'FullDay', 
                                      IF(@is_leave_existing = 1 AND @leave_shift_existing != v_leave_half, 'FullDay', v_leave_half));

            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
        END WHILE date_loop;
    END IF;

    COMMIT;

    -- ─── Return summary ───────────────────────────────────────────────────────
    SELECT
        p_leave_request_id                          AS leave_request_id,
        v_emp_id                                    AS employee_id,
        v_start_date                                AS start_date,
        v_end_date                                  AS end_date,
        v_leave_half                                AS leave_half_type,
        p_action                                    AS status,
        DATEDIFF(v_end_date, v_start_date) + 1      AS calendar_days,
        (SELECT total_days FROM leave_requests
         WHERE leave_request_id = p_leave_request_id) AS working_days_deducted;

END //

DELIMITER ;
