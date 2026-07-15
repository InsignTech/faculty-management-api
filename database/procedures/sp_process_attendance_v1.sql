DROP PROCEDURE IF EXISTS `sp_process_attendance_v1`;

DELIMITER ;;
CREATE PROCEDURE `sp_process_attendance_v1`(IN p_date DATE)
BEGIN

    DECLARE done     INT DEFAULT FALSE;
    DECLARE v_emp_id INT;

    DECLARE emp_cursor CURSOR FOR
        SELECT employee_id FROM employee WHERE active = 1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN emp_cursor;

    read_loop: LOOP

        FETCH emp_cursor INTO v_emp_id;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET @first_in  = NULL;
        SET @last_out  = NULL;

        SELECT 
            MIN(TIME(l.punch_time)),
            MAX(TIME(l.punch_time))
        INTO 
            @first_in,
            @last_out
        FROM attendance_detail_log l
        JOIN employee e 
            ON TRIM(e.employee_code) = TRIM(l.employee_code)
        WHERE e.employee_id = v_emp_id
        AND l.punch_time >= CONCAT(p_date, ' 00:00:00')
        AND l.punch_time <  CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00');

        
        SET done = FALSE;

        SET @holiday_type = NULL;

        SELECT holiday_type
        INTO @holiday_type
        FROM holiday_master
        WHERE p_date BETWEEN holiday_start_date AND holiday_end_date
        AND is_active = 1
        AND employee_id IN (v_emp_id, -1)
        ORDER BY CASE WHEN employee_id = v_emp_id THEN 1 ELSE 2 END
        LIMIT 1;

        
        SET done = FALSE;

        SET @is_worked = IF(@first_in IS NOT NULL, 1, 0);

        IF @holiday_type IS NOT NULL THEN

            INSERT INTO attendance_daily (
                employee_id, date, status,
                is_worked_on_holiday,
                first_in_time, last_out_time,
                worked_hours, deduction_days
            )
            VALUES (
                v_emp_id, p_date, @holiday_type,
                @is_worked,
                @first_in, @last_out,
                IF(@first_in IS NOT NULL AND @last_out IS NOT NULL,
                   ROUND(TIMESTAMPDIFF(
                        MINUTE,
                        TIMESTAMP(p_date, @first_in),
                        TIMESTAMP(p_date, @last_out)
                   ) / 60, 2),
                   0),
                0
            )
            ON DUPLICATE KEY UPDATE
                status               = @holiday_type,
                is_worked_on_holiday = @is_worked,
                first_in_time        = VALUES(first_in_time),
                last_out_time        = VALUES(last_out_time),
                worked_hours         = VALUES(worked_hours),
                deduction_days       = 0;

            ITERATE read_loop;

        END IF;

        IF @first_in IS NULL THEN

            INSERT INTO attendance_daily (
                employee_id, date, status, deduction_days
            )
            VALUES (
                v_emp_id, p_date, 'Absent', 1
            )
            ON DUPLICATE KEY UPDATE
                status         = 'Absent',
                deduction_days = 1;

            ITERATE read_loop;

        END IF;

        
        SET @fh_start    = NULL;
        SET @fh_end      = NULL;
        SET @sh_start    = NULL;
        SET @sh_end      = NULL;
        SET @start_grace = NULL;
        SET @end_grace   = NULL;

        SELECT 
            MAX(CASE WHEN shift_type = 'FirstHalf'  THEN start_time END),
            MAX(CASE WHEN shift_type = 'FirstHalf'  THEN end_time   END),
            MAX(CASE WHEN shift_type = 'SecondHalf' THEN start_time END),
            MAX(CASE WHEN shift_type = 'SecondHalf' THEN end_time   END),
            MAX(start_grace_mins),
            MAX(end_grace_mins)
        INTO 
            @fh_start, @fh_end,
            @sh_start, @sh_end,
            @start_grace, @end_grace
        FROM shift_master
        WHERE is_active = 1
        AND start_date <= p_date
        AND (end_date IS NULL OR end_date >= p_date)
        AND employee_id = (
            SELECT CASE 
                WHEN EXISTS (
                    SELECT 1 FROM shift_master
                    WHERE is_active = 1
                    AND start_date <= p_date
                    AND (end_date IS NULL OR end_date >= p_date)
                    AND employee_id = v_emp_id
                ) 
                THEN v_emp_id 
                ELSE -1 
            END
        );

        
        SET done = FALSE;

        
        IF @fh_start IS NULL THEN
            SET @fh_start    = '09:00:00';
            SET @fh_end      = '13:00:00';
            SET @sh_start    = '13:30:00';
            SET @sh_end      = '16:30:00';
            SET @start_grace = 15;
            SET @end_grace   = 5;
        END IF;

        SET @first_half = IF(
            @first_in <= ADDTIME(@fh_start, SEC_TO_TIME(@start_grace * 60))
            AND @last_out >= @fh_end, 1, 0
        );

        SET @second_half = IF(
            @first_in <= @sh_start
            AND @last_out >= SUBTIME(@sh_end, SEC_TO_TIME(@end_grace * 60)), 1, 0
        );

        IF @first_half = 1 AND @second_half = 1 THEN
            SET @shift_type = 'FullDay';
            SET @deduction  = 0;
        ELSEIF @first_half = 1 THEN
            SET @shift_type = 'FirstHalf';
            SET @deduction  = 0.5;
        ELSEIF @second_half = 1 THEN
            SET @shift_type = 'SecondHalf';
            SET @deduction  = 0.5;
        ELSE
            SET @shift_type = 'Absent';
            SET @deduction  = 1;
        END IF;

        SET @is_late      = 0;
        SET @late_minutes = 0;

        IF @shift_type IN ('FullDay', 'FirstHalf') THEN
            IF @first_in > ADDTIME(@fh_start, SEC_TO_TIME(@start_grace * 60)) THEN
                SET @is_late      = 1;
                SET @late_minutes = TIMESTAMPDIFF(
                    MINUTE,
                    TIMESTAMP(p_date, @fh_start),
                    TIMESTAMP(p_date, @first_in)
                );
            END IF;
        END IF;

        IF @shift_type = 'SecondHalf' THEN
            IF @first_in > ADDTIME(@sh_start, SEC_TO_TIME(@start_grace * 60)) THEN
                SET @is_late      = 1;
                SET @late_minutes = TIMESTAMPDIFF(
                    MINUTE,
                    TIMESTAMP(p_date, @sh_start),
                    TIMESTAMP(p_date, @first_in)
                );
            END IF;
        END IF;

        SET @is_early      = 0;
        SET @early_minutes = 0;

        IF @shift_type IN ('FullDay', 'SecondHalf') THEN
            IF @last_out < SUBTIME(@sh_end, SEC_TO_TIME(@end_grace * 60)) THEN
                SET @is_early      = 1;
                SET @early_minutes = TIMESTAMPDIFF(
                    MINUTE,
                    TIMESTAMP(p_date, @last_out),
                    TIMESTAMP(p_date, @sh_end)
                );
            END IF;
        END IF;

        IF @shift_type = 'FirstHalf' THEN
            IF @last_out < SUBTIME(@fh_end, SEC_TO_TIME(@end_grace * 60)) THEN
                SET @is_early      = 1;
                SET @early_minutes = TIMESTAMPDIFF(
                    MINUTE,
                    TIMESTAMP(p_date, @last_out),
                    TIMESTAMP(p_date, @fh_end)
                );
            END IF;
        END IF;

        IF @is_late = 1 AND @is_early = 1 THEN
            SET @deduction = @deduction + 0.5;
        END IF;

        INSERT INTO attendance_daily (
            employee_id, date,
            first_in_time, last_out_time,
            worked_hours,
            shift_type, status,
            is_late, late_minutes,
            is_early_leaving, early_minutes,
            deduction_days,
            is_worked_on_holiday
        )
        VALUES (
            v_emp_id, p_date,
            @first_in, @last_out,
            ROUND(TIMESTAMPDIFF(
                MINUTE,
                TIMESTAMP(p_date, @first_in),
                TIMESTAMP(p_date, @last_out)
            ) / 60, 2),
            @shift_type, 'Present',
            @is_late, @late_minutes,
            @is_early, @early_minutes,
            @deduction,
            0
        )
        ON DUPLICATE KEY UPDATE
            first_in_time        = VALUES(first_in_time),
            last_out_time        = VALUES(last_out_time),
            worked_hours         = VALUES(worked_hours),
            shift_type           = VALUES(shift_type),
            status               = VALUES(status),
            is_late              = VALUES(is_late),
            late_minutes         = VALUES(late_minutes),
            is_early_leaving     = VALUES(is_early_leaving),
            early_minutes        = VALUES(early_minutes),
            deduction_days       = VALUES(deduction_days),
            is_worked_on_holiday = VALUES(is_worked_on_holiday);

    END LOOP;

    CLOSE emp_cursor;

END ;;
DELIMITER ;
