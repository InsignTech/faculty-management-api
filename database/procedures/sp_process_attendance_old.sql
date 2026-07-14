DROP PROCEDURE IF EXISTS `sp_process_attendance_old`;

DELIMITER ;;
CREATE PROCEDURE `sp_process_attendance_old`(
    IN p_process_date DATE
)
BEGIN
    DECLARE v_employee_id       VARCHAR(45);
    DECLARE v_punch_time        DATETIME;
    DECLARE v_log_id            INT;
    DECLARE v_shift_id          INT;
    DECLARE v_shift_type        ENUM('FullDay','FirstHalf','SecondHalf');
    DECLARE v_start_time        TIME;
    DECLARE v_end_time          TIME;
    DECLARE v_start_grace       INT;
    DECLARE v_end_grace         INT;
    DECLARE v_half_start        TIME;
    DECLARE v_half_end          TIME;
    DECLARE v_half_grace_end    INT;
    DECLARE v_half_grace_start  INT;
    DECLARE v_punch_date        DATE;
    DECLARE v_punch_time_only   TIME;
    DECLARE v_is_late           TINYINT DEFAULT 0;
    DECLARE v_is_early          TINYINT DEFAULT 0;
    DECLARE v_type              ENUM('PunchIn','PunchOut');
    DECLARE v_shift_type_att    ENUM('First Half','Second Half','Full Day');
    DECLARE v_deduction         DECIMAL(3,2) DEFAULT 0.00;
    DECLARE v_attendance_id     INT;
    DECLARE v_existing_att_id   INT;
    DECLARE v_existing_punch    TIME;
    DECLARE v_punchin_att_id    INT;
    DECLARE v_punchin_time      TIME;
    DECLARE v_detail_exists     INT DEFAULT 0;
    DECLARE v_not_found         INT DEFAULT 0;

    DECLARE cur_punches CURSOR FOR
        SELECT log_id, employee_id, punch_time
        FROM attendance_detail_log
        WHERE DATE(punch_time) = p_process_date
          AND processed_flag IN (0, 2)
        ORDER BY employee_id, punch_time;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = 1;

    OPEN cur_punches;

    punch_loop: LOOP

        SET v_not_found = 0;
        FETCH cur_punches INTO v_log_id, v_employee_id, v_punch_time;
        IF v_not_found = 1 THEN LEAVE punch_loop; END IF;

        SET v_punch_date        = DATE(v_punch_time);
        SET v_punch_time_only   = TIME(v_punch_time);
        SET v_is_late           = 0;
        SET v_is_early          = 0;
        SET v_deduction         = 0.00;
        SET v_existing_att_id   = NULL;
        SET v_existing_punch    = NULL;
        SET v_punchin_att_id    = NULL;
        SET v_punchin_time      = NULL;
        SET v_shift_id          = NULL;
        SET v_half_end          = NULL;
        SET v_half_start        = NULL;
        SET v_half_grace_end    = 0;
        SET v_half_grace_start  = 0;

        
        
        
        SET v_not_found = 0;
        SELECT shift_id, shift_type, start_time, end_time,
               start_grace_mins, end_grace_mins
        INTO   v_shift_id, v_shift_type, v_start_time, v_end_time,
               v_start_grace, v_end_grace
        FROM shift_master
        WHERE (employee_id = CAST(v_employee_id AS SIGNED) OR employee_id = -1)
          AND start_date  <= v_punch_date
          AND (end_date IS NULL OR end_date >= v_punch_date)
          AND is_active   = 1
          AND shift_type  = 'FullDay'
        ORDER BY CASE WHEN employee_id = CAST(v_employee_id AS SIGNED) THEN 0 ELSE 1 END
        LIMIT 1;
        SET v_not_found = 0;

        IF v_shift_id IS NULL THEN
            UPDATE attendance_detail_log
            SET processed_flag = 2
            WHERE log_id = v_log_id;
            ITERATE punch_loop;
        END IF;

        
        
        
        SET v_not_found = 0;
        SELECT end_time, end_grace_mins
        INTO   v_half_end, v_half_grace_end
        FROM shift_master
        WHERE (employee_id = CAST(v_employee_id AS SIGNED) OR employee_id = -1)
          AND start_date  <= v_punch_date
          AND (end_date IS NULL OR end_date >= v_punch_date)
          AND is_active   = 1
          AND shift_type  = 'FirstHalf'
        ORDER BY CASE WHEN employee_id = CAST(v_employee_id AS SIGNED) THEN 0 ELSE 1 END
        LIMIT 1;
        SET v_not_found = 0;

        
        
        
        SET v_not_found = 0;
        SELECT start_time, start_grace_mins
        INTO   v_half_start, v_half_grace_start
        FROM shift_master
        WHERE (employee_id = CAST(v_employee_id AS SIGNED) OR employee_id = -1)
          AND start_date  <= v_punch_date
          AND (end_date IS NULL OR end_date >= v_punch_date)
          AND is_active   = 1
          AND shift_type  = 'SecondHalf'
        ORDER BY CASE WHEN employee_id = CAST(v_employee_id AS SIGNED) THEN 0 ELSE 1 END
        LIMIT 1;
        SET v_not_found = 0;

        
        
        
        SET v_not_found     = 0;
        SET v_detail_exists = 0;
        SELECT COUNT(*) INTO v_detail_exists
        FROM attendance_detail
        WHERE employee_id = v_employee_id
          AND punch_time  = v_punch_time;
        SET v_not_found = 0;

        IF v_detail_exists > 0 THEN
            UPDATE attendance_detail_log
            SET processed_flag = 1
            WHERE log_id = v_log_id;
            ITERATE punch_loop;
        END IF;

        
        
        
        SET v_not_found      = 0;
        SET v_punchin_att_id = NULL;
        SET v_punchin_time   = NULL;
        SELECT attendance_id, punch_time
        INTO   v_punchin_att_id, v_punchin_time
        FROM attendance
        WHERE employee_id = CAST(v_employee_id AS SIGNED)
          AND date        = v_punch_date
          AND type        = 'PunchIn'
        LIMIT 1;
        SET v_not_found = 0;

        
        
        
        IF v_punchin_att_id IS NULL THEN

            SET v_type      = 'PunchIn';
            SET v_deduction = 0.00;
            SET v_is_late   = 0;

            IF v_punch_time_only > ADDTIME(v_start_time, SEC_TO_TIME(v_start_grace * 60)) THEN
                SET v_is_late   = 1;
                SET v_deduction = 0.50;
            END IF;

            INSERT INTO attendance (
                employee_id, date, status, punch_type, type,
                shift_type, punch_time, created_on,
                is_late, is_early_leaving, is_regularized, deduction_days
            ) VALUES (
                CAST(v_employee_id AS SIGNED), v_punch_date,
                'Present', 'Biometric', 'PunchIn',
                'Full Day',
                v_punch_time_only, NOW(),
                v_is_late, 0, 0, v_deduction
            );

            SET v_attendance_id = LAST_INSERT_ID();

        ELSE

            
            
            
            SET v_not_found       = 0;
            SET v_existing_att_id = NULL;
            SET v_existing_punch  = NULL;
            SELECT attendance_id, punch_time
            INTO   v_existing_att_id, v_existing_punch
            FROM attendance
            WHERE employee_id = CAST(v_employee_id AS SIGNED)
              AND date        = v_punch_date
              AND type        = 'PunchOut'
              AND punch_time  IS NOT NULL
            LIMIT 1;
            SET v_not_found = 0;

            IF v_existing_att_id IS NULL THEN

                IF v_half_start IS NOT NULL
                   AND v_punchin_time >= v_half_start THEN
                    SET v_shift_type_att = 'Second Half';

                ELSEIF v_half_end IS NOT NULL
                   AND v_punch_time_only <= ADDTIME(v_half_end, SEC_TO_TIME(v_half_grace_end * 60)) THEN
                    SET v_shift_type_att = 'First Half';

                ELSE
                    SET v_shift_type_att = 'Full Day';
                END IF;

                SET v_is_early  = 0;
                SET v_deduction = 0.00;
                IF v_shift_type_att = 'Full Day' AND
                   v_punch_time_only < SUBTIME(v_end_time, SEC_TO_TIME(v_end_grace * 60)) THEN
                    SET v_is_early  = 1;
                    SET v_deduction = 0.50;
                END IF;

                DELETE FROM attendance
                WHERE employee_id = CAST(v_employee_id AS SIGNED)
                  AND date        = v_punch_date
                  AND type        = 'PunchOut'
                  AND punch_time  IS NULL;

                INSERT INTO attendance (
                    employee_id, date, status, punch_type, type,
                    shift_type, punch_time, created_on,
                    is_late, is_early_leaving, is_regularized, deduction_days
                ) VALUES (
                    CAST(v_employee_id AS SIGNED), v_punch_date,
                    'Present', 'Biometric', 'PunchOut',
                    v_shift_type_att, v_punch_time_only, NOW(),
                    0, v_is_early, 0, v_deduction
                );

                SET v_attendance_id = LAST_INSERT_ID();

                UPDATE attendance
                SET
                    shift_type = v_shift_type_att,
                    is_late = CASE
                        WHEN v_shift_type_att = 'Second Half'
                             AND v_punchin_time > ADDTIME(
                                 v_half_start,
                                 SEC_TO_TIME(v_half_grace_start * 60))
                        THEN 1
                        ELSE is_late
                    END,
                    deduction_days = CASE
                        WHEN v_shift_type_att IN ('First Half', 'Second Half') THEN 0.50
                        ELSE deduction_days
                    END
                WHERE attendance_id = v_punchin_att_id;

                IF v_shift_type_att IN ('First Half', 'Second Half') THEN
                    UPDATE attendance
                    SET deduction_days = 0.00
                    WHERE attendance_id = v_attendance_id;
                END IF;

            ELSE

                
                
                
                IF v_punch_time_only > v_existing_punch THEN

                    IF v_half_start IS NOT NULL
                       AND v_punchin_time >= v_half_start THEN
                        SET v_shift_type_att = 'Second Half';

                    ELSEIF v_half_end IS NOT NULL
                       AND v_punch_time_only <= ADDTIME(v_half_end, SEC_TO_TIME(v_half_grace_end * 60)) THEN
                        SET v_shift_type_att = 'First Half';

                    ELSE
                        SET v_shift_type_att = 'Full Day';
                    END IF;

                    SET v_is_early  = 0;
                    SET v_deduction = 0.00;
                    IF v_shift_type_att = 'Full Day' AND
                       v_punch_time_only < SUBTIME(v_end_time, SEC_TO_TIME(v_end_grace * 60)) THEN
                        SET v_is_early  = 1;
                        SET v_deduction = 0.50;
                    END IF;

                    UPDATE attendance
                    SET punch_time       = v_punch_time_only,
                        shift_type       = v_shift_type_att,
                        is_early_leaving = v_is_early,
                        deduction_days   = v_deduction
                    WHERE attendance_id  = v_existing_att_id;

                    UPDATE attendance
                    SET
                        shift_type     = v_shift_type_att,
                        deduction_days = CASE
                            WHEN v_shift_type_att IN ('First Half', 'Second Half') THEN 0.50
                            ELSE deduction_days
                        END
                    WHERE attendance_id = v_punchin_att_id;

                    SET v_attendance_id = v_existing_att_id;

                ELSE
                    UPDATE attendance_detail_log
                    SET processed_flag = 1
                    WHERE log_id = v_log_id;
                    ITERATE punch_loop;
                END IF;

            END IF;
        END IF;

        
        
        
        INSERT INTO attendance_detail (
            attandance_id, employee_id, punch_time, created_on
        ) VALUES (
            v_attendance_id, v_employee_id, v_punch_time, NOW()
        );

        
        
        
        UPDATE attendance_detail_log
        SET processed_flag = 1
        WHERE log_id = v_log_id;

    END LOOP;

    CLOSE cur_punches;

    
    
    
    
    
    INSERT INTO attendance (
        employee_id, date, status, punch_type, type,
        shift_type, punch_time, created_on,
        is_late, is_early_leaving, is_regularized, deduction_days
    )
    SELECT
        a.employee_id,
        a.date,
        'Present',
        'Biometric',
        'PunchOut',
        'Full Day',
        NULL,
        NOW(),
        0,
        1,
        0,
        0.50
    FROM attendance a
    WHERE a.date       = p_process_date
      AND a.type       = 'PunchIn'
      AND a.shift_type = 'Full Day'
      AND NOT EXISTS (
          SELECT 1
          FROM (
              SELECT employee_id
              FROM attendance
              WHERE date = p_process_date
                AND type = 'PunchOut'
          ) AS po
          WHERE po.employee_id = a.employee_id
      );

    
    
    
    
    
    
    UPDATE attendance a
    INNER JOIN (
        SELECT employee_id
        FROM (
            SELECT employee_id
            FROM attendance
            WHERE date       = p_process_date
              AND type       = 'PunchOut'
              AND punch_time IS NULL
        ) AS missing_po
    ) AS mp ON mp.employee_id = a.employee_id
    SET a.deduction_days = 0.50
    WHERE a.date       = p_process_date
      AND a.type       = 'PunchIn'
      AND a.shift_type = 'Full Day';

    SELECT CONCAT('Attendance processed for date: ', p_process_date) AS result;

END ;;
DELIMITER ;
