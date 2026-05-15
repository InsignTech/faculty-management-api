-- Comprehensive fix for Attendance Stored Procedures using attendance_daily schema
USE `staffdesk`;

DELIMITER //

-- 1. Update Get Attendance History
DROP PROCEDURE IF EXISTS `sp_get_employee_attendance` //
CREATE PROCEDURE `sp_get_employee_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        attendance_id,
        employee_id,
        DATE_FORMAT(date, '%Y-%m-%d') as date,
        first_in_time,
        last_out_time,
        worked_mins,
        shift_type,
        status,
        is_late,
        late_minutes,
        is_early_leaving,
        early_minutes,
        overtime_minutes,
        deduction_days,
        is_worked_on_holiday,
        regularization_shift_type,
        onduty_shift_type,
        is_leave,
        is_leave_type,
        leave_shift_type,
        created_on
    FROM attendance_daily 
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year
    ORDER BY date DESC;
END //

-- 2. Update Attendance Summary
DROP PROCEDURE IF EXISTS `sp_get_attendance_summary` //
CREATE PROCEDURE `sp_get_attendance_summary`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        COUNT(*) AS total_records,
        COUNT(CASE WHEN status NOT IN ('Present', 'Absent', 'Leave') THEN 1 END) AS holiday_count,
        (
            SELECT GROUP_CONCAT(CONCAT(status, ': ', cnt) SEPARATOR ' | ')
            FROM (
                SELECT status, COUNT(*) as cnt
                FROM attendance_daily
                WHERE employee_id = p_employee_id 
                  AND MONTH(date) = p_month 
                  AND YEAR(date) = p_year
                  AND status NOT IN ('Present', 'Absent', 'Leave')
                GROUP BY status
            ) t
        ) AS holiday_details,
        COUNT(CASE WHEN status = 'Present' THEN 1 END) AS present_count,
        CAST(SUM(CASE WHEN status = 'Present' THEN (1 - deduction_days) ELSE 0 END) AS DECIMAL(10,2)) AS net_present_days,
        COUNT(CASE WHEN status = 'Absent' THEN 1 END) AS absent_count,
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_count,
        SUM(CASE WHEN is_early_leaving = 1 THEN 1 ELSE 0 END) AS early_leaving_count,
        COUNT(CASE WHEN status = 'Absent' AND deduction_days = 1.0 AND first_in_time IS NULL THEN 1 END) AS full_absent_count,
        COALESCE(SUM(deduction_days), 0) AS total_deductions
    FROM attendance_daily
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year;
END //

-- 3. Update Irregular Attendance (for Regularization Page)
DROP PROCEDURE IF EXISTS `sp_get_irregular_attendance` //
CREATE PROCEDURE `sp_get_irregular_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        attendance_id,
        employee_id,
        DATE_FORMAT(date, '%Y-%m-%d') as date,
        first_in_time,
        last_out_time,
        worked_mins,
        shift_type,
        status,
        deduction_days,
        CASE
            -- FULL DAY ABSENT
            WHEN deduction_days = 1.0 AND status = 'Absent' THEN 'Full Day Missing'
            
            -- INCOMPLETE PUNCH (Mandatory 1.0 Deduction)
            WHEN deduction_days = 1.0 AND (first_in_time = last_out_time OR first_in_time IS NULL OR last_out_time IS NULL)
                THEN 'Incomplete Punch'

            -- HALF DAY ABSENT / LEAVE
            WHEN deduction_days = 0.5 AND status = 'Absent' AND shift_type = 'FirstHalf' THEN 'Second Half Missing'
            WHEN deduction_days = 0.5 AND status = 'Absent' AND shift_type = 'SecondHalf' THEN 'First Half Missing'
            WHEN deduction_days = 0.5 AND status = 'Leave' AND shift_type = 'FirstHalf' THEN 'Second Half Leave'
            WHEN deduction_days = 0.5 AND status = 'Leave' AND shift_type = 'SecondHalf' THEN 'First Half Leave'

            -- IRREGULAR (Late/Early)
            WHEN is_late = 1 AND is_early_leaving = 1 THEN 'Late & Early Leaving'
            WHEN is_late = 1 THEN 'Late Arrival'
            WHEN is_early_leaving = 1 THEN 'Early Leaving'
            
            ELSE 'Other Anomaly'
        END AS final_status
    FROM attendance_daily
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year
      AND (deduction_days > 0 OR is_late = 1 OR is_early_leaving = 1)
      AND (regularization_shift_type IS NULL AND onduty_shift_type IS NULL AND is_leave = 0)
    ORDER BY date DESC;
END //

-- 4. Revamped Log Processing (Syncs raw logs to attendance_daily)
DROP PROCEDURE IF EXISTS `sp_process_attendance_logs` //
CREATE PROCEDURE `sp_process_attendance_logs`(
    IN p_date DATE
)
BEGIN
    DECLARE v_grace_in TIME DEFAULT '09:15:00';
    DECLARE v_early_out TIME DEFAULT '16:05:00';
    DECLARE v_deduction_half DECIMAL(3,2) DEFAULT 0.50;
    DECLARE v_deduction_full DECIMAL(3,2) DEFAULT 1.00;

    -- Load settings
    SELECT setting_value INTO v_grace_in FROM attendance_settings WHERE setting_key = 'grace_in_time';
    SELECT setting_value INTO v_early_out FROM attendance_settings WHERE setting_key = 'early_out_threshold';
    SELECT CAST(setting_value AS DECIMAL(3,2)) INTO v_deduction_half FROM attendance_settings WHERE setting_key = 'deduction_amount';

    -- Insert/Update logic
    INSERT INTO attendance_daily (
        employee_id, date, first_in_time, last_out_time, 
        worked_mins, status, is_late, late_minutes, 
        is_early_leaving, early_minutes, deduction_days, shift_type
    )
    SELECT 
        adl.employee_id,
        adl.date,
        MIN(adl.time) as first_in,
        MAX(adl.time) as last_out,
        TIMESTAMPDIFF(MINUTE, MIN(adl.time), MAX(adl.time)) as worked,
        'Present',
        IF(MIN(adl.time) > v_grace_in, 1, 0) as late,
        IF(MIN(adl.time) > v_grace_in, TIMESTAMPDIFF(MINUTE, v_grace_in, MIN(adl.time)), 0),
        IF(MAX(adl.time) < v_early_out, 1, 0) as early,
        IF(MAX(adl.time) < v_early_out, TIMESTAMPDIFF(MINUTE, MAX(adl.time), v_early_out), 0),
        -- Deduction Logic: 1.0 for single punch, 0.5 for late/early (if threshold met)
        CASE 
            WHEN MIN(adl.time) = MAX(adl.time) THEN v_deduction_full
            WHEN MIN(adl.time) > v_grace_in OR MAX(adl.time) < v_early_out THEN v_deduction_half
            ELSE 0.00
        END as deduction,
        'FullDay'
    FROM attendance_detail_log adl
    INNER JOIN employee e ON adl.employee_id = e.employee_id
    WHERE adl.date = p_date AND e.active = 1
    GROUP BY adl.employee_id, adl.date
    ON DUPLICATE KEY UPDATE 
        first_in_time = VALUES(first_in_time),
        last_out_time = VALUES(last_out_time),
        worked_mins = VALUES(worked_mins),
        is_late = VALUES(is_late),
        late_minutes = VALUES(late_minutes),
        is_early_leaving = VALUES(is_early_leaving),
        early_minutes = VALUES(early_minutes),
        -- Don't overwrite deduction if it was already regularized
        deduction_days = IF(is_regularized = 1, deduction_days, VALUES(deduction_days)),
        status = 'Present';

    SELECT ROW_COUNT() AS processed_rows;
END //

DELIMITER ;
