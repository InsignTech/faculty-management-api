DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_sync_attendance`$$

CREATE PROCEDURE `sp_sync_attendance`()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_emp_id INT;
    DECLARE v_date DATE;
    DECLARE v_first_in TIME;
    DECLARE v_last_out TIME;

    -- Holiday
    DECLARE v_holiday_type VARCHAR(50);
    DECLARE v_worked_on_holiday TINYINT;
    DECLARE v_worked_mins INT;

    -- Shift master (FullDay / FirstHalf / SecondHalf)
    DECLARE v_fd_start TIME; DECLARE v_fd_end TIME; DECLARE v_fd_gs INT; DECLARE v_fd_ge INT;
    DECLARE v_fh_start TIME; DECLARE v_fh_end TIME; DECLARE v_fh_gs INT; DECLARE v_fh_ge INT;
    DECLARE v_sh_start TIME; DECLARE v_sh_end TIME; DECLARE v_sh_gs INT; DECLARE v_sh_ge INT;

    -- Grace boundaries
    DECLARE v_fd_grace_start_limit TIME; DECLARE v_fd_grace_end_limit TIME;
    DECLARE v_fh_grace_start_limit TIME; DECLARE v_fh_grace_end_limit TIME;
    DECLARE v_sh_grace_start_limit TIME; DECLARE v_sh_grace_end_limit TIME;

    -- FullDay result
    DECLARE v_fd_is_late TINYINT; DECLARE v_fd_late_mins INT;
    DECLARE v_fd_is_early TINYINT; DECLARE v_fd_early_mins INT;

    -- FirstHalf result
    DECLARE v_fh_status VARCHAR(30); DECLARE v_fh_deduction DECIMAL(3,2);
    DECLARE v_fh_is_late TINYINT; DECLARE v_fh_late_mins INT;
    DECLARE v_fh_is_early TINYINT; DECLARE v_fh_early_mins INT;

    -- SecondHalf result
    DECLARE v_sh_status VARCHAR(30); DECLARE v_sh_deduction DECIMAL(3,2);
    DECLARE v_sh_is_late TINYINT; DECLARE v_sh_late_mins INT;
    DECLARE v_sh_is_early TINYINT; DECLARE v_sh_early_mins INT;

    -- Worked minutes per half, based on overlap of punch times with each half's shift window
    DECLARE v_fh_worked_mins INT;
    DECLARE v_sh_worked_mins INT;

    DECLARE cur1 CURSOR FOR
        SELECT employee_id, date, first_in_time, last_out_time
        FROM attendance_daily
        ORDER BY date ASC, employee_id ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur1;

    read_loop: LOOP
        FETCH cur1 INTO v_emp_id, v_date, v_first_in, v_last_out;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET v_holiday_type = NULL;

        -- Clear any existing rows for this employee/date (uk_emp_date = employee_id, date, shift_type)
        DELETE FROM attendance WHERE employee_id = v_emp_id AND date = v_date;

        -- ============================================================
        -- 1. HOLIDAY CHECK (employee-specific row wins over -1 default)
        -- ============================================================
        SET v_holiday_type = (
            SELECT holiday_type
            FROM holiday_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date BETWEEN holiday_start_date AND holiday_end_date
              AND is_active = 1
            ORDER BY employee_id DESC
            LIMIT 1
        );

        IF v_holiday_type IS NOT NULL THEN
            SET v_worked_on_holiday = IF(v_first_in IS NOT NULL AND v_last_out IS NOT NULL, 1, 0);
            SET v_worked_mins = 0;
            IF v_first_in IS NOT NULL AND v_last_out IS NOT NULL THEN
                SET v_worked_mins = TIMESTAMPDIFF(MINUTE, v_first_in, v_last_out);
                IF v_worked_mins < 0 THEN SET v_worked_mins = v_worked_mins + 1440; END IF;
            END IF;

            INSERT INTO attendance
                (employee_id, date, first_in_time, last_out_time, worked_mins, shift_type, status,
                 deduction_days, is_worked_on_holiday)
            VALUES
                (v_emp_id, v_date, v_first_in, v_last_out, v_worked_mins, 'FullDay', v_holiday_type,
                 0.00, v_worked_on_holiday);

            -- Overrides can still apply on a holiday date (e.g. a leave request logged that day)
            UPDATE attendance a
            JOIN attendance_regularization r
              ON a.employee_id = r.employee_id AND a.date = r.date
            SET a.status = IF(r.request_type = 'Regularization', 'Regularized', 'OnDuty'),
                a.deduction_days = 0.00
            WHERE a.employee_id = v_emp_id AND a.date = v_date AND r.status = 'Approved'
              AND (r.regularization_shift_type = 'FullDay' OR a.shift_type = r.regularization_shift_type);

            UPDATE attendance a
            JOIN leave_requests l
              ON a.employee_id = l.employee_id AND a.date BETWEEN l.start_date AND l.end_date
            SET a.status = 'Leave',
                a.deduction_days = IF(COALESCE(l.is_paid, 1) = 1, 0.00, IF(a.shift_type = 'FullDay', 1.00, 0.50))
            WHERE a.employee_id = v_emp_id AND a.date = v_date AND l.status = 'Approved'
              AND (l.leave_half_type = 'FullDay' OR a.shift_type = l.leave_half_type);

            ITERATE read_loop;
        END IF;

        -- ============================================================
        -- 2. SHIFT MASTER LOOKUP (employee-specific row wins over -1)
        -- ============================================================
        SET v_fd_start = (
            SELECT start_time FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'FullDay' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_fd_end = (
            SELECT end_time FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'FullDay' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_fd_gs = (
            SELECT start_grace_mins FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'FullDay' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_fd_ge = (
            SELECT end_grace_mins FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'FullDay' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        IF v_fd_start IS NULL THEN
            SET v_fd_start = '09:00:00', v_fd_end = '16:30:00', v_fd_gs = 21, v_fd_ge = 30;
        END IF;

        SET v_fh_start = (
            SELECT start_time FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'FirstHalf' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_fh_end = (
            SELECT end_time FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'FirstHalf' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_fh_gs = (
            SELECT start_grace_mins FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'FirstHalf' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_fh_ge = (
            SELECT end_grace_mins FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'FirstHalf' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        IF v_fh_start IS NULL THEN
            SET v_fh_start = '09:00:00', v_fh_end = '13:00:00', v_fh_gs = 21, v_fh_ge = 30;
        END IF;

        SET v_sh_start = (
            SELECT start_time FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'SecondHalf' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_sh_end = (
            SELECT end_time FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'SecondHalf' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_sh_gs = (
            SELECT start_grace_mins FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'SecondHalf' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        SET v_sh_ge = (
            SELECT end_grace_mins FROM shift_master
            WHERE (employee_id = v_emp_id OR employee_id = -1)
              AND v_date >= start_date AND (end_date IS NULL OR v_date <= end_date)
              AND shift_type = 'SecondHalf' AND is_active = 1
            ORDER BY employee_id DESC LIMIT 1
        );
        IF v_sh_start IS NULL THEN
            SET v_sh_start = '13:00:00', v_sh_end = '16:30:00', v_sh_gs = 0, v_sh_ge = 30;
        END IF;

        -- ============================================================
        -- 3. NO PUNCH OR SINGLE PUNCH ONLY -> Absent, FullDay, 1.00
        -- ============================================================
        IF v_first_in IS NULL OR v_last_out IS NULL THEN
            INSERT INTO attendance
                (employee_id, date, first_in_time, last_out_time, shift_type, status, deduction_days, worked_mins)
            VALUES
                (v_emp_id, v_date, v_first_in, v_last_out, 'FullDay', 'Absent', 1.00, 0);
        ELSE
            -- FullDay grace window: e.g. in <= 09:21 and out >= 16:00
            SET v_fd_grace_start_limit = ADDTIME(v_fd_start, SEC_TO_TIME(v_fd_gs * 60));
            SET v_fd_grace_end_limit   = SUBTIME(v_fd_end, SEC_TO_TIME(v_fd_ge * 60));

            IF v_first_in <= v_fd_grace_start_limit AND v_last_out >= v_fd_grace_end_limit THEN
                -- ---------------- FullDay Present ----------------
                SET v_worked_mins = TIMESTAMPDIFF(MINUTE, v_first_in, v_last_out);
                IF v_worked_mins < 0 THEN SET v_worked_mins = v_worked_mins + 1440; END IF;

                -- Within grace on both ends by definition of this branch -> not late, not early
                SET v_fd_is_late = 0;
                SET v_fd_late_mins = 0;
                SET v_fd_is_early = 0;
                SET v_fd_early_mins = 0;

                INSERT INTO attendance
                    (employee_id, date, first_in_time, last_out_time, worked_mins, shift_type, status,
                     deduction_days, is_late, late_minutes, is_early_leaving, early_minutes)
                VALUES
                    (v_emp_id, v_date, v_first_in, v_last_out, v_worked_mins, 'FullDay', 'Present',
                     0.00, v_fd_is_late, v_fd_late_mins, v_fd_is_early, v_fd_early_mins);
            ELSE
                -- ---------------- Split: FirstHalf + SecondHalf ----------------
                SET v_worked_mins = TIMESTAMPDIFF(MINUTE, v_first_in, v_last_out);
                IF v_worked_mins < 0 THEN SET v_worked_mins = v_worked_mins + 1440; END IF;

                -- FirstHalf: late if in >= 09:21, early/absent if out < 12:30
                SET v_fh_grace_start_limit = ADDTIME(v_fh_start, SEC_TO_TIME(v_fh_gs * 60));
                SET v_fh_grace_end_limit   = SUBTIME(v_fh_end, SEC_TO_TIME(v_fh_ge * 60));

                IF v_first_in >= v_fh_grace_start_limit THEN
                    SET v_fh_status = 'Absent', v_fh_deduction = 0.50,
                        v_fh_is_late = 1, v_fh_late_mins = TIMESTAMPDIFF(MINUTE, v_fh_start, v_first_in),
                        v_fh_is_early = 0, v_fh_early_mins = 0;
                ELSEIF v_last_out < v_fh_grace_end_limit THEN
                    SET v_fh_status = 'Absent', v_fh_deduction = 0.50,
                        v_fh_is_late = 0, v_fh_late_mins = 0,
                        v_fh_is_early = 1, v_fh_early_mins = TIMESTAMPDIFF(MINUTE, v_last_out, v_fh_end);
                ELSE
                    SET v_fh_status = 'Present', v_fh_deduction = 0.00,
                        v_fh_is_late = 0, v_fh_late_mins = 0,
                        v_fh_is_early = 0, v_fh_early_mins = 0;
                END IF;

                INSERT INTO attendance
                    (employee_id, date, first_in_time, last_out_time, worked_mins, shift_type, status,
                     deduction_days, is_late, late_minutes, is_early_leaving, early_minutes)
                VALUES
                    (v_emp_id, v_date, v_first_in, v_last_out, ROUND(v_worked_mins / 2), 'FirstHalf', v_fh_status,
                     v_fh_deduction, v_fh_is_late, v_fh_late_mins, v_fh_is_early, v_fh_early_mins);

                -- SecondHalf: late if in >= 13:00, early/absent if out < 16:00
                SET v_sh_grace_start_limit = ADDTIME(v_sh_start, SEC_TO_TIME(v_sh_gs * 60));
                SET v_sh_grace_end_limit   = SUBTIME(v_sh_end, SEC_TO_TIME(v_sh_ge * 60));

                IF v_first_in >= v_sh_grace_start_limit THEN
                    SET v_sh_status = 'Absent', v_sh_deduction = 0.50,
                        v_sh_is_late = 1, v_sh_late_mins = TIMESTAMPDIFF(MINUTE, v_sh_start, v_first_in),
                        v_sh_is_early = 0, v_sh_early_mins = 0;
                ELSEIF v_last_out < v_sh_grace_end_limit THEN
                    SET v_sh_status = 'Absent', v_sh_deduction = 0.50,
                        v_sh_is_late = 0, v_sh_late_mins = 0,
                        v_sh_is_early = 1, v_sh_early_mins = TIMESTAMPDIFF(MINUTE, v_last_out, v_sh_end);
                ELSE
                    SET v_sh_status = 'Present', v_sh_deduction = 0.00,
                        v_sh_is_late = 0, v_sh_late_mins = 0,
                        v_sh_is_early = 0, v_sh_early_mins = 0;
                END IF;

                INSERT INTO attendance
                    (employee_id, date, first_in_time, last_out_time, worked_mins, shift_type, status,
                     deduction_days, is_late, late_minutes, is_early_leaving, early_minutes)
                VALUES
                    (v_emp_id, v_date, v_first_in, v_last_out, ROUND(v_worked_mins / 2), 'SecondHalf', v_sh_status,
                     v_sh_deduction, v_sh_is_late, v_sh_late_mins, v_sh_is_early, v_sh_early_mins);
            END IF;
        END IF;

        -- ============================================================
        -- 4. OVERRIDE: Regularization (approved, matching shift_type or FullDay)
        -- ============================================================
        UPDATE attendance a
        JOIN attendance_regularization r
          ON a.employee_id = r.employee_id AND a.date = r.date
        SET a.status = IF(r.request_type = 'Regularization', 'Regularized', 'OnDuty'),
            a.deduction_days = 0.00
        WHERE a.employee_id = v_emp_id AND a.date = v_date AND r.status = 'Approved'
          AND (r.regularization_shift_type = 'FullDay' OR a.shift_type = r.regularization_shift_type);

        -- ============================================================
        -- 5. OVERRIDE: Leave (approved, matching half or FullDay)
        -- ============================================================
        UPDATE attendance a
        JOIN leave_requests l
          ON a.employee_id = l.employee_id AND a.date BETWEEN l.start_date AND l.end_date
        SET a.status = 'Leave',
            a.deduction_days = IF(COALESCE(l.is_paid, 1) = 1, 0.00, IF(a.shift_type = 'FullDay', 1.00, 0.50))
        WHERE a.employee_id = v_emp_id AND a.date = v_date AND l.status = 'Approved'
          AND (l.leave_half_type = 'FullDay' OR a.shift_type = l.leave_half_type);

    END LOOP;

    CLOSE cur1;
END$$

DELIMITER ;