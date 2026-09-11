DROP PROCEDURE IF EXISTS `sp_approve_leave`;

DELIMITER ;;
CREATE PROCEDURE `sp_approve_leave`(
    IN p_leave_request_id INT,
    IN p_approved_by      INT,
    IN p_action           ENUM('Approved','Rejected'),
    IN p_rejection_reason TEXT,
    IN p_substitute_id    INT
)
proc: BEGIN

    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_leave_type     VARCHAR(50);
    DECLARE v_leave_half     VARCHAR(20);
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_current_date   DATE;
    DECLARE v_is_paid        TINYINT DEFAULT 1;

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
        status,
        is_paid
    INTO
        v_emp_id,
        v_start_date,
        v_end_date,
        v_leave_type,
        v_leave_half,
        v_current_status,
        v_is_paid
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
        status                 = p_action,
        approved_by_id         = p_approved_by,
        approved_on            = NOW(),
        rejection_reason       = IF(p_action = 'Rejected', p_rejection_reason, NULL),
        substitute_employee_id = COALESCE(p_substitute_id, substitute_employee_id)
    WHERE leave_request_id = p_leave_request_id;

    -- ── Phase 1: Validation Loop (Conflict check) ──
    IF p_action = 'Approved' THEN
        SET v_current_date = v_start_date;
        validation_loop: WHILE v_current_date <= v_end_date DO
            SET @has_full_day_conflict = EXISTS (
                SELECT 1 FROM attendance 
                WHERE employee_id = v_emp_id AND date = v_current_date 
                  AND status IN ('Leave', 'Regularized', 'OnDuty') AND shift_type = 'FullDay'
            );
            SET @has_fh_conflict = EXISTS (
                SELECT 1 FROM attendance 
                WHERE employee_id = v_emp_id AND date = v_current_date 
                  AND status IN ('Leave', 'Regularized', 'OnDuty') AND shift_type = 'FirstHalf'
            );
            SET @has_sh_conflict = EXISTS (
                SELECT 1 FROM attendance 
                WHERE employee_id = v_emp_id AND date = v_current_date 
                  AND status IN ('Leave', 'Regularized', 'OnDuty') AND shift_type = 'SecondHalf'
            );

            IF @has_full_day_conflict THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: One or more days already have an approved leave or regularization';
            END IF;

            IF v_leave_half = 'FullDay' AND (@has_fh_conflict OR @has_sh_conflict) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: Part of this day is already covered. Cannot apply full-day leave.';
            END IF;

            IF v_leave_half = 'FirstHalf' AND @has_fh_conflict THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: First half is already covered by leave or regularization';
            END IF;

            IF v_leave_half = 'SecondHalf' AND @has_sh_conflict THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: Second half is already covered by leave or regularization';
            END IF;

            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
        END WHILE;

        -- ── Phase 2: Update employee_leaves table ──
        SET @v_total_days = 0;
        SELECT total_days INTO @v_total_days FROM leave_requests WHERE leave_request_id = p_leave_request_id;
        
        INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
        VALUES (v_emp_id, v_leave_type, DATE_FORMAT(v_start_date, '%m-%Y'), 0, 0, @v_total_days)
        ON DUPLICATE KEY UPDATE 
            leaves_taken = leaves_taken + @v_total_days;

        -- ── Phase 3: Rebuild attendance records using sp_process_attendance_shiftwise ──
        SET v_current_date = v_start_date;
        date_loop: WHILE v_current_date <= v_end_date DO
            CALL sp_process_attendance_shiftwise(v_current_date);
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

END ;;
DELIMITER ;
