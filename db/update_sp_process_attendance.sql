USE `staffdesk`;
DROP PROCEDURE IF EXISTS `sp_process_attendance`;
DELIMITER //
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

        -- ── Skip already-regularized rows ──────────────────────────────────────
        BEGIN
            DECLARE v_reg_check VARCHAR(20) DEFAULT NULL;
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_reg_check = NULL;

            SELECT regularization_shift_type INTO v_reg_check
            FROM   attendance_daily
            WHERE  employee_id = v_emp_id
              AND  date        = p_date
            LIMIT  1;

            IF v_reg_check IS NOT NULL THEN
                ITERATE read_loop;
            END IF;
        END;

        -- ── Punch log ──────────────────────────────────────────────────────────
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

        -- ── Holiday check ──────────────────────────────────────────────────────
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT holiday_type
            INTO   v_holiday_type
            FROM   holiday_master
            WHERE  p_date BETWEEN holiday_start_date AND holiday_end_date
              AND  is_active   = 1
              AND  employee_id IN (v_emp_id, -1)
            ORDER BY CASE WHEN employee_id = -1 THEN 1 ELSE 2 END
            LIMIT 1;
        END;

        SET v_is_worked = IF(v_first_in IS NOT NULL, 1, 0);

        -- ── Holiday branch ─────────────────────────────────────────────────────
        IF v_holiday_type IS NOT NULL THEN

            INSERT INTO attendance_daily (
                employee_id, date, status,
                is_worked_on_holiday,
                first_in_time, last_out_time,
                worked_mins, deduction_days,
                is_leave, leave_shift_type,
                regularization_shift_type,
                onduty_shift_type,
                created_on
            )
            VALUES (
                v_emp_id, p_date, v_holiday_type,
                v_is_worked,
                v_first_in, v_last_out,
                IF(v_first_in IS NOT NULL AND v_last_out IS NOT NULL
                   AND v_first_in != v_last_out,
                   TIMESTAMPDIFF(MINUTE,
                       TIMESTAMP(p_date, v_first_in),
                       TIMESTAMP(p_date, v_last_out)), 0),
                0,
                0, NULL,
                NULL, NULL,
                NOW()
            )
            ON DUPLICATE KEY UPDATE
                status                    = v_holiday_type,
                is_worked_on_holiday      = v_is_worked,
                first_in_time             = VALUES(first_in_time),
                last_out_time             = VALUES(last_out_time),
                worked_mins               = VALUES(worked_mins),
                deduction_days            = 0,
                is_leave                  = 0,
                leave_shift_type          = NULL,
                regularization_shift_type = NULL,
                onduty_shift_type         = NULL;

            UPDATE attendance_detail_log l
            JOIN   employee e
                ON TRIM(e.employee_code) = TRIM(l.employee_code)
            SET    l.processed_flag = 1
            WHERE  e.employee_id    = v_emp_id
              AND  l.punch_time    >= CONCAT(p_date, ' 00:00:00')
              AND  l.punch_time     < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
              AND  l.processed_flag = 0;

            ITERATE read_loop;

        END IF;

        -- ── Leave check ────────────────────────────────────────────────────────
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT
                lr.leave_type,
                COALESCE(lr.leave_half_type, 'FullDay')
            INTO
                v_leave_type,
                v_leave_half
            FROM leave_requests lr
            WHERE lr.employee_id = v_emp_id
              AND lr.status      = 'Approved'
              AND p_date BETWEEN lr.start_date AND lr.end_date
            ORDER BY lr.leave_request_id DESC
            LIMIT 1;
        END;

        -- ── No punch-in → Absent ───────────────────────────────────────────────
        -- shift_type is always FullDay when there is no punch data.
        -- Leave metadata is stored independently; status stays Absent (no punch = no attendance).
        -- deduction_days = 0 when on leave, 1 otherwise.
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
                IF(v_leave_type IS NOT NULL, 0, 1),
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

            ITERATE read_loop;

        END IF;

        -- ── Shift resolution ───────────────────────────────────────────────────
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

        -- ── Grace boundary calculation ─────────────────────────────────────────
        SET v_fd_grace_in  = CAST(ADDTIME(v_fd_start, SEC_TO_TIME(v_fd_start_grace * 60)) AS TIME);
        SET v_fd_grace_out = CAST(SUBTIME(v_fd_end,   SEC_TO_TIME(v_fd_end_grace   * 60)) AS TIME);
        SET v_fh_grace_in  = CAST(ADDTIME(v_fh_start, SEC_TO_TIME(v_fh_start_grace * 60)) AS TIME);
        SET v_fh_grace_out = CAST(SUBTIME(v_fh_end,   SEC_TO_TIME(v_fh_end_grace   * 60)) AS TIME);
        SET v_sh_grace_in  = CAST(ADDTIME(v_sh_start, SEC_TO_TIME(v_sh_start_grace * 60)) AS TIME);
        SET v_sh_grace_out = CAST(SUBTIME(v_sh_end,   SEC_TO_TIME(v_sh_end_grace   * 60)) AS TIME);

        -- ── No punch-out flag ──────────────────────────────────────────────────
        SET v_no_punch_out = IF(v_first_in = v_last_out, 1, 0);

        -- ── Shift classification ───────────────────────────────────────────────
        IF v_first_in <= v_fd_grace_in
            AND v_last_out >= v_fd_grace_out
            AND v_no_punch_out = 0 THEN
            SET v_shift_type = 'FullDay';
            SET v_deduction  = 0;

        ELSEIF v_first_in  <= v_fh_grace_in
            AND v_last_out  >= v_fh_grace_out
            AND v_last_out   < v_fd_grace_out
            AND v_no_punch_out = 0 THEN
            SET v_shift_type = 'FirstHalf';
            SET v_deduction  = 0.5;

        ELSEIF v_first_in  >  v_fh_grace_in
            AND v_first_in  <= v_sh_grace_in
            AND v_last_out  >= v_sh_grace_out
            AND v_no_punch_out = 0 THEN
            SET v_shift_type = 'SecondHalf';
            SET v_deduction  = 0.5;

        ELSEIF v_no_punch_out = 1 THEN
            -- Punched in but never punched out → full day absent
            SET v_shift_type = 'FullDay';
            SET v_deduction  = 1.00;

        ELSE
            IF v_last_out <= v_fh_end THEN
                SET v_shift_type = 'FirstHalf';
                SET v_deduction  = 0.5;
            ELSEIF v_first_in >= v_sh_start THEN
                SET v_shift_type = 'SecondHalf';
                SET v_deduction  = 0.5;
            ELSE
                SET v_shift_type = 'FullDay';
                SET v_deduction  = 0;
            END IF;
        END IF;

        -- ── Late-in detection ──────────────────────────────────────────────────
        IF v_shift_type IN ('FullDay', 'FirstHalf') THEN
            IF v_first_in > v_fd_grace_in THEN
                SET v_is_late      = 1;
                SET v_late_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(p_date, v_fd_start),
                    TIMESTAMP(p_date, v_first_in));
            END IF;
        END IF;

        IF v_shift_type = 'SecondHalf' THEN
            IF v_first_in > v_sh_grace_in THEN
                SET v_is_late      = 1;
                SET v_late_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(p_date, v_sh_start),
                    TIMESTAMP(p_date, v_first_in));
            END IF;
        END IF;

        -- ── Early-leaving detection ────────────────────────────────────────────
        IF v_shift_type = 'FullDay' THEN
            IF v_last_out < v_fd_grace_out THEN
                SET v_is_early      = 1;
                SET v_early_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(p_date, v_last_out),
                    TIMESTAMP(p_date, v_fd_end));
            END IF;
        END IF;

        IF v_shift_type = 'FirstHalf' THEN
            -- Left after first-half end but before full-day grace out
            -- → completed FirstHalf but left early from full-day perspective
            -- → is_early is informational; deduction stays 0.50, status stays Present
            IF v_last_out > v_fh_end AND v_last_out < v_fd_grace_out THEN
                SET v_is_early      = 1;
                SET v_early_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(p_date, v_last_out),
                    TIMESTAMP(p_date, v_fd_end));
            -- Left before even completing first half
            ELSEIF v_last_out <= v_fh_end AND v_last_out < v_fh_grace_out THEN
                SET v_is_early      = 1;
                SET v_early_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(p_date, v_last_out),
                    TIMESTAMP(p_date, v_fh_end));
            END IF;
        END IF;

        IF v_shift_type = 'SecondHalf' THEN
            IF v_last_out < v_sh_grace_out THEN
                SET v_is_early      = 1;
                SET v_early_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(p_date, v_last_out),
                    TIMESTAMP(p_date, v_sh_end));
            END IF;
        END IF;

        -- ── No punch-out: clear early flag ────────────────────────────────────
        IF v_no_punch_out = 1 THEN
            SET v_is_early      = 0;
            SET v_early_minutes = 0;
        END IF;

        -- ── Deduction penalties (shift_type never changes) ────────────────────
        IF v_shift_type = 'FullDay' THEN
            IF v_is_late = 1 AND v_is_early = 1 THEN
                SET v_deduction = 1.00;
            ELSEIF v_is_late = 1 OR v_is_early = 1 THEN
                SET v_deduction = v_deduction + 0.5;
            END IF;
        END IF;

        IF v_shift_type = 'FirstHalf' THEN
            IF v_is_late = 1 OR v_is_early = 1 THEN
                -- Only penalise to 1.00 if they didn't complete first half
                -- (left at or before fh_end); otherwise deduction stays 0.50
                IF v_last_out <= v_fh_end THEN
                    SET v_deduction = 1.00;
                END IF;
            END IF;
        END IF;

        IF v_shift_type = 'SecondHalf' THEN
            IF v_is_late = 1 OR v_is_early = 1 THEN
                SET v_deduction = 1.00;
            END IF;
        END IF;

        IF v_deduction > 1.0 THEN SET v_deduction = 1.0; END IF;

        -- ── Snapshot punch-only deduction for status derivation ───────────────
        -- Status (Present/Absent) must reflect attendance reality, not leave.
        -- We freeze v_deduction here, before leave adjusts it.
        SET v_punch_deduction = v_deduction;

        -- ── Half-day leave adjustments (deduction cap only, never touch status) ──
        IF v_leave_type IS NOT NULL AND v_leave_half = 'FirstHalf' THEN
            SET v_deduction    = IF(v_deduction > 0.5, 0.5, v_deduction);
            SET v_is_late      = 0;
            SET v_late_minutes = 0;
        END IF;

        IF v_leave_type IS NOT NULL AND v_leave_half = 'SecondHalf' THEN
            SET v_deduction     = IF(v_deduction > 0.5, 0.5, v_deduction);
            SET v_is_early      = 0;
            SET v_early_minutes = 0;
        END IF;

        -- ── Full-day leave: deduction = 0 (employee is covered) ───────────────
        IF v_leave_type IS NOT NULL AND v_leave_half = 'FullDay' THEN
            SET v_deduction = 0;
        END IF;

        -- ── Overtime: only clean FullDay (no late, no early) ──────────────────
        IF v_shift_type = 'FullDay' AND v_is_late = 0 AND v_is_early = 0 THEN
            IF v_last_out > v_fd_end THEN
                SET v_overtime_mins = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(p_date, v_fd_end),
                    TIMESTAMP(p_date, v_last_out));
            END IF;
        END IF;

        -- ── Worked minutes ─────────────────────────────────────────────────────
        IF v_no_punch_out = 0 THEN
            SET v_worked_mins = TIMESTAMPDIFF(MINUTE,
                TIMESTAMP(p_date, v_first_in),
                TIMESTAMP(p_date, v_last_out));
        END IF;

        -- ── Final upsert ───────────────────────────────────────────────────────
        -- status derives from v_punch_deduction (pure attendance),
        -- deduction_days uses v_deduction (leave-adjusted).
        INSERT INTO attendance_daily (
            employee_id, date,
            first_in_time, last_out_time,
            worked_mins,
            shift_type, status,
            is_late, late_minutes,
            is_early_leaving, early_minutes,
            overtime_minutes,
            deduction_days,
            is_worked_on_holiday,
            is_leave, leave_shift_type,
            regularization_shift_type,
            onduty_shift_type,
            created_on
        )
        VALUES (
            v_emp_id, p_date,
            v_first_in,
            IF(v_no_punch_out = 1, NULL, v_last_out),
            v_worked_mins,
            v_shift_type,
            IF(v_punch_deduction = 1.00, 'Absent', 'Present'),
            v_is_late,    v_late_minutes,
            v_is_early,   v_early_minutes,
            v_overtime_mins,
            v_deduction,
            0,
            IF(v_leave_type IS NOT NULL, 1, 0),
            CASE
                WHEN v_leave_type IS NULL        THEN NULL
                WHEN v_leave_half = 'FullDay'    THEN 'FullDay'
                WHEN v_leave_half = 'FirstHalf'  THEN 'FirstHalf'
                WHEN v_leave_half = 'SecondHalf' THEN 'SecondHalf'
                ELSE NULL
            END,
            NULL,
            NULL,
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
            leave_shift_type          = VALUES(leave_shift_type),
            regularization_shift_type = regularization_shift_type,  -- preserve
            onduty_shift_type         = onduty_shift_type;           -- preserve

        -- ── Mark punches processed ─────────────────────────────────────────────
        UPDATE attendance_detail_log l
        JOIN   employee e
            ON TRIM(e.employee_code) = TRIM(l.employee_code)
        SET    l.processed_flag = 1
        WHERE  e.employee_id    = v_emp_id
          AND  l.punch_time    >= CONCAT(p_date, ' 00:00:00')
          AND  l.punch_time     < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
          AND  l.processed_flag = 0;

    END LOOP;

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

END //
DELIMITER ;