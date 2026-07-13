DELIMITER $$
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_process_attendance`(IN p_date DATE)
BEGIN

    DECLARE done       INT DEFAULT FALSE;
    DECLARE v_emp_id   INT;

    DECLARE v_first_in    TIME    DEFAULT NULL;
    DECLARE v_last_out    TIME    DEFAULT NULL;
    DECLARE v_worked_mins INT     DEFAULT 0;

    DECLARE v_holiday_type VARCHAR(50)  DEFAULT NULL;
    DECLARE v_is_worked    TINYINT      DEFAULT 0;
    DECLARE v_leave_type   VARCHAR(100) DEFAULT NULL;
    DECLARE v_leave_half   VARCHAR(20)  DEFAULT 'FullDay';
    DECLARE v_is_paid      TINYINT      DEFAULT 1;

    DECLARE v_emp_shift_id INT DEFAULT -1;

    DECLARE v_fd_start       TIME DEFAULT '09:00:00';
    DECLARE v_fd_end         TIME DEFAULT '16:30:00';
    DECLARE v_fd_start_grace INT  DEFAULT 15;
    DECLARE v_fd_end_grace   INT  DEFAULT 25;

    DECLARE v_fh_start       TIME DEFAULT '09:00:00';
    DECLARE v_fh_end         TIME DEFAULT '13:00:00';
    DECLARE v_fh_start_grace INT  DEFAULT 15;
    DECLARE v_fh_end_grace   INT  DEFAULT 5;

    DECLARE v_sh_start       TIME DEFAULT '13:30:00';
    DECLARE v_sh_end         TIME DEFAULT '16:30:00';
    DECLARE v_sh_start_grace INT  DEFAULT 0;
    DECLARE v_sh_end_grace   INT  DEFAULT 5;

    DECLARE v_fd_grace_in  TIME DEFAULT NULL;
    DECLARE v_fd_grace_out TIME DEFAULT NULL;
    DECLARE v_fh_grace_in  TIME DEFAULT NULL;
    DECLARE v_fh_grace_out TIME DEFAULT NULL;
    DECLARE v_sh_grace_in  TIME DEFAULT NULL;
    DECLARE v_sh_grace_out TIME DEFAULT NULL;

    DECLARE v_no_punch_out       TINYINT      DEFAULT 0;
    DECLARE v_shift_type         VARCHAR(20)  DEFAULT 'FullDay';
    DECLARE v_deduction          DECIMAL(3,2) DEFAULT 1.00;
    -- Punch-only deduction captured before any leave adjustments;
    -- used exclusively to derive status so leave never influences Present/Absent.
    DECLARE v_punch_deduction    DECIMAL(3,2) DEFAULT 1.00;
    DECLARE v_is_late            TINYINT      DEFAULT 0;
    DECLARE v_late_minutes       INT          DEFAULT 0;
    DECLARE v_is_early           TINYINT      DEFAULT 0;
    DECLARE v_early_minutes      INT          DEFAULT 0;
    DECLARE v_overtime_mins      INT          DEFAULT 0;

    DECLARE emp_cursor CURSOR FOR
        SELECT employee_id FROM employee WHERE active = 1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN emp_cursor;

    SET SQL_SAFE_UPDATES = 0;
    SET SESSION MAX_EXECUTION_TIME = 120000;

    read_loop: LOOP

        FETCH emp_cursor INTO v_emp_id;
        IF done THEN LEAVE read_loop; END IF;

        -- ── Reset all variables ────────────────────────────────────────────────
        SET done              = FALSE;
        SET v_first_in        = NULL;
        SET v_last_out        = NULL;
        SET v_worked_mins     = 0;
        SET v_holiday_type    = NULL;
        SET v_is_worked       = 0;
        SET v_leave_type      = NULL;
        SET v_leave_half      = 'FullDay';
        SET v_is_paid         = 1;
        SET v_emp_shift_id    = -1;
        SET v_fd_start        = '09:00:00';
        SET v_fd_end          = '16:30:00';
        SET v_fd_start_grace  = 15;
        SET v_fd_end_grace    = 25;
        SET v_fh_start        = '09:00:00';
        SET v_fh_end          = '13:00:00';
        SET v_fh_start_grace  = 15;
        SET v_fh_end_grace    = 5;
        SET v_sh_start        = '13:30:00';
        SET v_sh_end          = '16:30:00';
        SET v_sh_start_grace  = 0;
        SET v_sh_end_grace    = 5;
        SET v_no_punch_out    = 0;
        SET v_shift_type      = 'FullDay';
        SET v_deduction       = 1.00;
        SET v_punch_deduction = 1.00;
        SET v_is_late         = 0;
        SET v_late_minutes    = 0;
        SET v_is_early        = 0;
        SET v_early_minutes   = 0;
        SET v_overtime_mins   = 0;

        -- ── Skip already-regularized or on-duty rows ───────────────────────────
        BEGIN
            DECLARE v_reg_check VARCHAR(20) DEFAULT NULL;
            DECLARE v_od_check VARCHAR(20) DEFAULT NULL;
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT regularization_shift_type, onduty_shift_type 
            INTO v_reg_check, v_od_check
            FROM   attendance_daily
            WHERE  employee_id = v_emp_id
              AND  date        = p_date
            LIMIT  1;

            IF v_reg_check IS NOT NULL OR v_od_check IS NOT NULL THEN
                ITERATE read_loop;
            END IF;
        END;

        -- ── Shift resolution (Query shift_master directly) ────────────────────
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT CASE
                WHEN EXISTS (
                    SELECT 1 FROM shift_master
                    WHERE is_active   = 1
                      AND start_date <= p_date
                      AND (end_date IS NULL OR end_date >= p_date)
                      AND employee_id = v_emp_id
                ) THEN v_emp_id
                ELSE -1
            END INTO v_emp_shift_id;
        END;

        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
            SELECT start_time, end_time, start_grace_mins, end_grace_mins
            INTO   v_fd_start, v_fd_end, v_fd_start_grace, v_fd_end_grace
            FROM   shift_master
            WHERE  is_active   = 1
              AND  start_date <= p_date
              AND  (end_date IS NULL OR end_date >= p_date)
              AND  employee_id = v_emp_shift_id
              AND  shift_type  = 'FullDay'
            LIMIT  1;
        END;

        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
            SELECT start_time, end_time, start_grace_mins, end_grace_mins
            INTO   v_fh_start, v_fh_end, v_fh_start_grace, v_fh_end_grace
            FROM   shift_master
            WHERE  is_active   = 1
              AND  start_date <= p_date
              AND  (end_date IS NULL OR end_date >= p_date)
              AND  employee_id = v_emp_shift_id
              AND  shift_type  = 'FirstHalf'
            LIMIT  1;
        END;

        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
            SELECT start_time, end_time, start_grace_mins, end_grace_mins
            INTO   v_sh_start, v_sh_end, v_sh_start_grace, v_sh_end_grace
            FROM   shift_master
            WHERE  is_active   = 1
              AND  start_date <= p_date
              AND  (end_date IS NULL OR end_date >= p_date)
              AND  employee_id = v_emp_shift_id
              AND  shift_type  = 'SecondHalf'
            LIMIT  1;
        END;

        -- Derive grace limits
        SET v_fd_grace_in  = ADDTIME(v_fd_start, SEC_TO_TIME(v_fd_start_grace * 60));
        SET v_fd_grace_out = SUBTIME(v_fd_end, SEC_TO_TIME(v_fd_end_grace * 60));
        SET v_fh_grace_in  = ADDTIME(v_fh_start, SEC_TO_TIME(v_fh_start_grace * 60));
        SET v_fh_grace_out = SUBTIME(v_fh_end, SEC_TO_TIME(v_fh_end_grace * 60));
        SET v_sh_grace_in  = ADDTIME(v_sh_start, SEC_TO_TIME(v_sh_start_grace * 60));
        SET v_sh_grace_out = SUBTIME(v_sh_end, SEC_TO_TIME(v_sh_end_grace * 60));

        -- ── Punch data ────────────────────────────────────────────────────────
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT
                MIN(TIME(l.punch_time)),
                MAX(TIME(l.punch_time))
            INTO
                v_first_in,
                v_last_out
            FROM attendance_detail_log l
            JOIN employee e
                ON TRIM(e.employee_code) = TRIM(l.employee_code)
            WHERE e.employee_id = v_emp_id
              AND l.punch_time >= CONCAT(p_date, ' 00:00:00')
              AND l.punch_time <  CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00');
        END;

        -- Calculate worked minutes
        IF v_first_in IS NOT NULL AND v_last_out IS NOT NULL AND v_first_in != v_last_out THEN
            SET v_worked_mins = TIMESTAMPDIFF(MINUTE, 
                                    TIMESTAMP(p_date, v_first_in), 
                                    TIMESTAMP(p_date, v_last_out));
        ELSE
            SET v_worked_mins = 0;
        END IF;

        -- ── Holiday Check ──────────────────────────────────────────────────────
        SELECT holiday_type 
        INTO v_holiday_type
        FROM holiday_master
        WHERE p_date BETWEEN holiday_start_date AND holiday_end_date
          AND is_active = 1
          AND (employee_id IS NULL OR employee_id = 0 OR employee_id = v_emp_id)
        ORDER BY holiday_id DESC
        LIMIT 1;

        IF v_holiday_type IS NULL THEN
            IF DAYNAME(p_date) IN ('Sunday', 'Saturday') THEN
                SET v_holiday_type = 'WeekEnd';
            END IF;
        END IF;

        -- ── Skip check-in logic if Holiday / Weekend (No Punches required) ──────
        IF v_holiday_type IS NOT NULL AND v_first_in IS NULL THEN
            
            INSERT INTO attendance_daily (
                employee_id, date, status, 
                shift_type, worked_mins, 
                deduction_days, 
                created_on
            )
            VALUES (
                v_emp_id, p_date, v_holiday_type, 
                'FullDay', 0, 0.00, NOW()
            )
            ON DUPLICATE KEY UPDATE
                status         = v_holiday_type,
                shift_type     = 'FullDay',
                worked_mins    = 0,
                deduction_days = 0.00;

            -- If weekend / holiday is processed, clear regularization logs
            UPDATE regularization_logs l
            SET l.processed_flag = 1
            WHERE l.employee_id = v_emp_id 
              AND l.regularization_date = p_date 
              AND l.processed_flag = 0;

            ITERATE read_loop;

        END IF;

        -- ── Leave check ────────────────────────────────────────────────────────
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT
                lr.leave_type,
                COALESCE(lr.leave_half_type, 'FullDay'),
                lr.is_paid
            INTO
                v_leave_type,
                v_leave_half,
                v_is_paid
            FROM leave_requests lr
            WHERE lr.employee_id = v_emp_id
              AND lr.status      = 'Approved'
              AND p_date BETWEEN lr.start_date AND lr.end_date
            ORDER BY lr.leave_request_id DESC
            LIMIT 1;
        END;

        -- ── No punch-in → Absent ───────────────────────────────────────────────
        IF v_first_in IS NULL THEN

            INSERT INTO attendance_daily (
                employee_id, date, status,
                shift_type, worked_mins,
                deduction_days,
                is_leave, leave_shift_type,
                regularization_shift_type,
                onduty_shift_type,
                created_on
            )
            VALUES (
                v_emp_id, p_date,
                'Absent',
                'FullDay',
                0,
                IF(v_leave_type IS NOT NULL, IF(v_is_paid = 1, 0, 1), 1),
                IF(v_leave_type IS NOT NULL, 1, 0),
                CASE
                    WHEN v_leave_type IS NULL        THEN NULL
                    WHEN v_leave_half = 'FirstHalf'  THEN 'FirstHalf'
                    WHEN v_leave_half = 'SecondHalf' THEN 'SecondHalf'
                    ELSE 'FullDay'
                END,
                NULL, NULL,
                NOW()
            )
            ON DUPLICATE KEY UPDATE
                status                    = 'Absent',
                shift_type                = 'FullDay',
                worked_mins               = 0,
                deduction_days            = VALUES(deduction_days),
                is_leave                  = VALUES(is_leave),
                leave_shift_type          = VALUES(leave_shift_type),
                regularization_shift_type = NULL,
                onduty_shift_type         = NULL;

            UPDATE regularization_logs l
            SET l.processed_flag = 1
            WHERE l.employee_id = v_emp_id 
              AND l.regularization_date = p_date 
              AND l.processed_flag = 0;

            ITERATE read_loop;

        END IF;

        -- ── Single punch → Incomplete punch → 1.0 Deduction ───────────────────
        IF v_first_in = v_last_out THEN
            SET v_deduction = 1.00;
            SET v_no_punch_out = 1;
        ELSE
            -- ── Double punch → Evaluate times ─────────────────────────────────
            -- Calculate Lateness (grace matches s.fd_start_grace)
            IF v_first_in > v_fd_grace_in THEN
                SET v_is_late = 1;
                SET v_late_minutes = TIMESTAMPDIFF(MINUTE, v_fd_start, v_first_in);
            END IF;

            -- Calculate Early leaving (grace matches s.fd_end_grace)
            IF v_last_out < v_fd_grace_out THEN
                SET v_is_early = 1;
                SET v_early_minutes = TIMESTAMPDIFF(MINUTE, v_last_out, v_fd_end);
            END IF;

            -- Base Deduction calculations
            IF v_is_late = 1 AND v_is_early = 1 THEN
                SET v_deduction = 1.00;
            ELSEIF v_is_late = 1 OR v_is_early = 1 THEN
                SET v_deduction = 0.50;
            ELSE
                SET v_deduction = 0.00;
            END IF;

            -- ── Special adjustment: Underworked hours ────────────────────────
            IF v_worked_mins < 240 THEN
                SET v_deduction = 1.00;
            ELSEIF v_worked_mins < 420 AND v_deduction < 0.50 THEN
                SET v_deduction = 0.50;
            END IF;
        END IF;

        -- If weekend / holiday is worked, mark it as Present and v_deduction = 0
        IF v_holiday_type IS NOT NULL THEN
            SET v_deduction = 0.00;
            SET v_is_worked = 1;
        END IF;

        IF v_deduction > 1.0 THEN SET v_deduction = 1.0; END IF;

        -- ── Snapshot punch-only deduction for status derivation ───────────────
        SET v_punch_deduction = v_deduction;

        -- ── Half-day leave adjustments (deduction cap only, never touch status) ──
        IF v_leave_type IS NOT NULL AND v_leave_half = 'FirstHalf' THEN
            IF v_is_paid = 1 THEN
                SET v_deduction    = IF(v_deduction > 0.5, 0.5, v_deduction);
            ELSE
                SET v_deduction    = IF(v_deduction < 0.5, 0.5, v_deduction);
            END IF;
            SET v_is_late      = 0;
            SET v_late_minutes = 0;
        END IF;

        IF v_leave_type IS NOT NULL AND v_leave_half = 'SecondHalf' THEN
            IF v_is_paid = 1 THEN
                SET v_deduction     = IF(v_deduction > 0.5, 0.5, v_deduction);
            ELSE
                SET v_deduction     = IF(v_deduction < 0.5, 0.5, v_deduction);
            END IF;
            SET v_is_early      = 0;
            SET v_early_minutes = 0;
        END IF;

        -- ── Full-day leave: deduction = 0 (employee is covered) ───────────────
        IF v_leave_type IS NOT NULL AND v_leave_half = 'FullDay' THEN
            SET v_deduction = IF(v_is_paid = 1, 0, 1.0);
        END IF;

        -- ── Overtime: only clean FullDay (no late, no early) ──────────────────
        IF v_deduction = 0.00 AND v_worked_mins > 480 AND v_is_worked = 0 THEN
            SET v_overtime_mins = v_worked_mins - 480;
        END IF;

        -- Derive status based exclusively on raw punch quality (punch-only deduction)
        SET v_shift_type = CASE
            WHEN v_punch_deduction = 1.00 THEN 'FullDay'
            WHEN v_is_late = 1            THEN 'SecondHalf'
            WHEN v_is_early = 1           THEN 'FirstHalf'
            ELSE 'FullDay'
        END;

        SET v_shift_type = IF(v_worked_mins < 420 AND v_worked_mins >= 240, 'FirstHalf', v_shift_type);

        IF v_holiday_type IS NOT NULL THEN
            SET v_shift_type = 'FullDay';
        END IF;

        -- Write record
        INSERT INTO attendance_daily (
            employee_id, date, first_in_time, last_out_time, worked_mins,
            shift_type, status,
            is_late, late_minutes,
            is_early_leaving, early_minutes,
            overtime_minutes, deduction_days,
            is_worked_on_holiday,
            is_leave, is_leave_type, leave_shift_type,
            created_on
        )
        VALUES (
            v_emp_id, p_date, v_first_in, v_last_out, v_worked_mins,
            v_shift_type,
            IF(v_holiday_type IS NOT NULL, v_holiday_type, IF(v_punch_deduction = 1.00, 'Absent', 'Present')),
            v_is_late, v_late_minutes,
            v_is_early, v_early_minutes,
            v_overtime_mins, v_deduction,
            v_is_worked,
            IF(v_leave_type IS NOT NULL, 1, 0),
            v_leave_type,
            IF(v_leave_type IS NOT NULL, v_leave_half, NULL),
            NOW()
        )
        ON DUPLICATE KEY UPDATE
            first_in_time             = VALUES(first_in_time),
            last_out_time             = VALUES(last_out_time),
            worked_mins               = VALUES(worked_mins),
            shift_type                = VALUES(shift_type),
            status                    = VALUES(status),
            is_late                   = VALUES(is_late),
            late_minutes              = VALUES(late_minutes),
            is_early_leaving          = VALUES(is_early_leaving),
            early_minutes             = VALUES(early_minutes),
            overtime_minutes          = VALUES(overtime_minutes),
            deduction_days            = VALUES(deduction_days),
            is_worked_on_holiday      = VALUES(is_worked_on_holiday),
            is_leave                  = VALUES(is_leave),
            is_leave_type             = VALUES(is_leave_type),
            leave_shift_type          = VALUES(leave_shift_type),
            regularization_shift_type = regularization_shift_type,
            onduty_shift_type         = onduty_shift_type;

        -- Clear regularization log flags
        UPDATE regularization_logs l
        SET l.processed_flag = 1
        WHERE l.employee_id = v_emp_id 
          AND l.regularization_date = p_date 
          AND l.processed_flag = 0;

        -- ── Mark punches processed ─────────────────────────────────────────────
        UPDATE attendance_detail_log l
        JOIN   employee e
            ON TRIM(e.employee_code) = TRIM(l.employee_code)
        SET    l.processed_flag = 1
        WHERE  e.employee_id    = v_emp_id
          AND  l.punch_time    >= CONCAT(p_date, ' 00:00:00')
          AND  l.punch_time     < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
          AND  l.processed_flag = 0;

    END LOOP read_loop;

    CLOSE emp_cursor;

    -- 1. Identify and log punches for inactive employees
    INSERT INTO attendance_invalid_log (employee_id, punch_time, reason)
    SELECT l.employee_code, l.punch_time, 'Inactive employee'
    FROM attendance_detail_log l
    JOIN employee e ON TRIM(e.employee_code) = TRIM(l.employee_code)
    WHERE l.punch_time >= CONCAT(p_date, ' 00:00:00')
      AND l.punch_time < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
      AND l.processed_flag = 0
      AND e.active = 0;

    -- 2. Identify and log punches for unknown/unmatched employee codes
    INSERT INTO attendance_invalid_log (employee_id, punch_time, reason)
    SELECT l.employee_code, l.punch_time, 'Unknown employee code'
    FROM attendance_detail_log l
    LEFT JOIN employee e ON TRIM(e.employee_code) = TRIM(l.employee_code)
    WHERE l.punch_time >= CONCAT(p_date, ' 00:00:00')
      AND l.punch_time < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
      AND l.processed_flag = 0
      AND e.employee_id IS NULL;

    -- 3. Mark all remaining unprocessed logs for this date as processed_flag = 2
    UPDATE attendance_detail_log l
    SET l.processed_flag = 2
    WHERE l.punch_time >= CONCAT(p_date, ' 00:00:00')
      AND l.punch_time < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
      AND l.processed_flag = 0;

    SET SESSION MAX_EXECUTION_TIME = 0;
    SET SQL_SAFE_UPDATES = 1;

END$$
DELIMITER ;
