DROP PROCEDURE IF EXISTS `sp_apply_regularization`;

DELIMITER ;;
CREATE PROCEDURE `sp_apply_regularization`(
    IN p_reg_id     INT,   
    IN p_approved_by INT   
)
BEGIN
    
    DECLARE v_emp_id   INT;
    DECLARE v_date     DATE;
    DECLARE v_in_time  TIME;
    DECLARE v_out_time TIME;
    DECLARE v_reg_type ENUM('Regularization','OnDuty');
    DECLARE v_regularization_shift_type ENUM('FullDay','FirstHalf','SecondHalf');
    DECLARE v_status   VARCHAR(20);

    SELECT employee_id, date, requested_in_time, requested_out_time,
           request_type, status, regularization_shift_type
    INTO   v_emp_id, v_date, v_in_time, v_out_time, v_reg_type, v_status,v_regularization_shift_type
    FROM   attendance_regularization
    WHERE  id = p_reg_id;

    
    IF v_status != 'Approved' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regularization request is not in Approved status';
    END IF;

    
    UPDATE attendance_regularization
    SET    status      = 'Approved',
           approved_by = p_approved_by,
           approved_on = NOW()
    WHERE  id = p_reg_id;

    
    SET @emp_shift_id = -1;
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM shift_master
            WHERE is_active = 1
              AND start_date <= v_date
              AND (end_date IS NULL OR end_date >= v_date)
              AND employee_id = v_emp_id
        ) THEN v_emp_id ELSE -1
    END INTO @emp_shift_id;

    
    SET @fd_start = '09:00:00'; SET @fd_end = '16:30:00';
    SET @fd_start_grace = 15;   SET @fd_end_grace = 25;
    SELECT start_time, end_time, start_grace_mins, end_grace_mins
    INTO   @fd_start, @fd_end, @fd_start_grace, @fd_end_grace
    FROM   shift_master
    WHERE  is_active = 1 AND start_date <= v_date
      AND  (end_date IS NULL OR end_date >= v_date)
      AND  employee_id = @emp_shift_id AND shift_type = 'FullDay' LIMIT 1;

    
    SET @fh_start = '09:00:00'; SET @fh_end = '13:00:00';
    SET @fh_start_grace = 15;   SET @fh_end_grace = 5;
    SELECT start_time, end_time, start_grace_mins, end_grace_mins
    INTO   @fh_start, @fh_end, @fh_start_grace, @fh_end_grace
    FROM   shift_master
    WHERE  is_active = 1 AND start_date <= v_date
      AND  (end_date IS NULL OR end_date >= v_date)
      AND  employee_id = @emp_shift_id AND shift_type = 'FirstHalf' LIMIT 1;

    
    SET @sh_start = '13:30:00'; SET @sh_end = '16:30:00';
    SET @sh_start_grace = 0;    SET @sh_end_grace = 5;
    SELECT start_time, end_time, start_grace_mins, end_grace_mins
    INTO   @sh_start, @sh_end, @sh_start_grace, @sh_end_grace
    FROM   shift_master
    WHERE  is_active = 1 AND start_date <= v_date
      AND  (end_date IS NULL OR end_date >= v_date)
      AND  employee_id = @emp_shift_id AND shift_type = 'SecondHalf' LIMIT 1;

    
    SET @fd_grace_in  = CAST(ADDTIME(@fd_start, SEC_TO_TIME(@fd_start_grace * 60)) AS TIME);
    SET @fd_grace_out = CAST(SUBTIME(@fd_end,   SEC_TO_TIME(@fd_end_grace   * 60)) AS TIME);
    SET @fh_grace_in  = CAST(ADDTIME(@fh_start, SEC_TO_TIME(@fh_start_grace * 60)) AS TIME);
    SET @fh_grace_out = CAST(SUBTIME(@fh_end,   SEC_TO_TIME(@fh_end_grace   * 60)) AS TIME);
    SET @sh_grace_in  = CAST(ADDTIME(@sh_start, SEC_TO_TIME(@sh_start_grace * 60)) AS TIME);
    SET @sh_grace_out = CAST(SUBTIME(@sh_end,   SEC_TO_TIME(@sh_end_grace   * 60)) AS TIME);

    SET @first_in  = CAST(v_in_time  AS TIME);
    SET @last_out  = CAST(v_out_time AS TIME);

    
    IF v_reg_type = 'OnDuty' THEN
        SET @shift_type = 'FullDay';
        SET @deduction  = 0;
        SET @is_late    = 0; SET @late_minutes  = 0;
        SET @is_early   = 0; SET @early_minutes = 0;
        SET @overtime_minutes = 0;
        SET @worked_mins = TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(v_date, @first_in),
            TIMESTAMP(v_date, @last_out));

    
    ELSE
        SET @no_punch_out = IF(@first_in = @last_out OR v_out_time IS NULL, 1, 0);

        
        IF @first_in <= @fd_grace_in AND @last_out >= @fd_grace_out AND @no_punch_out = 0 THEN
            SET @shift_type = 'FullDay';  SET @deduction = 0;
        ELSEIF @first_in <= @fh_grace_in AND @last_out >= @fh_grace_out
               AND @last_out < @fd_grace_out AND @no_punch_out = 0 THEN
            SET @shift_type = 'FirstHalf'; SET @deduction = 0.5;
        ELSEIF @first_in > @fh_grace_in AND @first_in <= @sh_grace_in
               AND @last_out >= @sh_grace_out AND @no_punch_out = 0 THEN
            SET @shift_type = 'SecondHalf'; SET @deduction = 0.5;
        ELSE
            SET @shift_type = 'Absent'; SET @deduction = 1;
        END IF;

        
        SET @is_late = 0; SET @late_minutes = 0;
        IF @shift_type IN ('FullDay','FirstHalf','Absent') THEN
            IF @first_in > @fd_grace_in THEN
                SET @is_late = 1;
                SET @late_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(v_date, @fd_start), TIMESTAMP(v_date, @first_in));
            END IF;
        END IF;
        IF @shift_type = 'SecondHalf' THEN
            IF @first_in > @sh_grace_in THEN
                SET @is_late = 1;
                SET @late_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(v_date, @sh_start), TIMESTAMP(v_date, @first_in));
            END IF;
        END IF;

        SET @is_early = 0; SET @early_minutes = 0;
        IF @shift_type = 'FullDay' AND @last_out < @fd_grace_out THEN
            SET @is_early = 1;
            SET @early_minutes = TIMESTAMPDIFF(MINUTE,
                TIMESTAMP(v_date, @last_out), TIMESTAMP(v_date, @fd_end));
        END IF;
        IF @shift_type IN ('FirstHalf','SecondHalf','Absent') THEN
            IF @last_out < @fd_grace_out THEN
                SET @is_early = 1;
                SET @early_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(v_date, @last_out), TIMESTAMP(v_date, @fd_end));
            END IF;
        END IF;

        
        IF @is_late = 1 AND @is_early = 1 THEN SET @deduction = @deduction + 0.5; END IF;
        IF @deduction > 1.0 THEN SET @deduction = 1.0; END IF;

        
        SET @overtime_minutes = 0;
        IF @shift_type = 'FullDay' AND @last_out > CAST(@fd_end AS TIME) THEN
            SET @overtime_minutes = TIMESTAMPDIFF(MINUTE,
                TIMESTAMP(v_date, @fd_end), TIMESTAMP(v_date, @last_out));
        END IF;

        
        SET @worked_mins = 0;
        IF @no_punch_out = 0 THEN
            SET @worked_mins = TIMESTAMPDIFF(MINUTE,
                TIMESTAMP(v_date, @first_in), TIMESTAMP(v_date, @last_out));
        END IF;
    END IF;

    
    UPDATE attendance_daily
    SET
        first_in_time        = @first_in,
        last_out_time        = IF(v_out_time IS NULL, NULL, @last_out),
        worked_mins          = @worked_mins,
        shift_type           = @shift_type,
        status               = IF(@shift_type = 'Absent', 'Absent', 'Present'),
        is_late              = @is_late,
        late_minutes         = @late_minutes,
        is_early_leaving     = @is_early,
        early_minutes        = @early_minutes,
        overtime_minutes     = @overtime_minutes,
        deduction_days       = @deduction,
        is_regularized       = 1,
        is_regularize_type   = v_reg_type,
        regularization_shift_type=v_regularization_shift_type
    WHERE employee_id = v_emp_id
      AND date        = v_date;

END ;;
DELIMITER ;
