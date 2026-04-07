-- Attendance Logic: Advanced processing with thresholds and regularization rules
USE `staffdesk`;

DELIMITER //

-- Revamped Procedure: Process Raw Logs into Attendance Table
DROP PROCEDURE IF EXISTS `sp_process_attendance_logs` //
CREATE PROCEDURE `sp_process_attendance_logs`(
    IN p_date DATE
)
BEGIN
    DECLARE v_grace_in_time TIME;
    DECLARE v_early_out_threshold TIME;
    DECLARE v_deduction_val DECIMAL(3,2);
    
    -- 1. Load thresholds from settings
    SELECT setting_value INTO v_grace_in_time FROM attendance_settings WHERE setting_key = 'grace_in_time';
    SELECT setting_value INTO v_early_out_threshold FROM attendance_settings WHERE setting_key = 'early_out_threshold';
    SELECT CAST(setting_value AS DECIMAL(3,2)) INTO v_deduction_val FROM attendance_settings WHERE setting_key = 'deduction_amount';
    
    -- Fallback to defaults if settings are missing
    SET v_grace_in_time = COALESCE(v_grace_in_time, '09:15:00');
    SET v_early_out_threshold = COALESCE(v_early_out_threshold, '16:05:00');
    SET v_deduction_val = COALESCE(v_deduction_val, 0.5);

    -- 2. Process Punch-Ins (Minimum time of the day)
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_late, deduction_days)
    SELECT 
        employee_id, 
        date, 
        'Present', 
        'Biometric', 
        'PunchIn', 
        'Full Day', 
        MIN(time),
        IF(MIN(time) > v_grace_in_time, 1, 0),
        IF(MIN(time) > v_grace_in_time, v_deduction_val, 0.00)
    FROM attendance_detail_log
    WHERE date = p_date
    GROUP BY employee_id, date
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_late = VALUES(is_late),
        deduction_days = IF(VALUES(is_late) = 1 OR is_early_leaving = 1, v_deduction_val, 0.00),
        status = 'Present';

    -- 3. Process Punch-Outs (Maximum time of the day - only if multiple punches exist)
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_early_leaving, deduction_days)
    SELECT 
        employee_id, 
        date, 
        'Present', 
        'Biometric', 
        'PunchOut', 
        'Full Day', 
        MAX(time),
        IF(MAX(time) < v_early_out_threshold, 1, 0),
        IF(MAX(time) < v_early_out_threshold, v_deduction_val, 0.00)
    FROM attendance_detail_log
    WHERE date = p_date
    GROUP BY employee_id, date
    HAVING COUNT(*) > 1
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_early_leaving = VALUES(is_early_leaving),
        deduction_days = IF(is_late = 1 OR VALUES(is_early_leaving) = 1, v_deduction_val, 0.00),
        status = 'Present';
        
    SELECT ROW_COUNT() AS processed_rows;
END //

-- [NEW] Procedure: Handle Regularization Approval and Recalculate Deductions
DROP PROCEDURE IF EXISTS `sp_handle_regularization_approval` //
CREATE PROCEDURE `sp_handle_regularization_approval`(
    IN p_employee_id INT,
    IN p_date DATE
)
BEGIN
    DECLARE v_max_waived INT;
    DECLARE v_current_month_count INT;
    DECLARE v_deduction_val DECIMAL(3,2);
    
    -- 1. Load configuration
    SELECT CAST(setting_value AS UNSIGNED) INTO v_max_waived FROM attendance_settings WHERE setting_key = 'max_waived_instances';
    SELECT CAST(setting_value AS DECIMAL(3,2)) INTO v_deduction_val FROM attendance_settings WHERE setting_key = 'deduction_amount';
    
    SET v_max_waived = COALESCE(v_max_waived, 3);
    SET v_deduction_val = COALESCE(v_deduction_val, 0.5);

    -- 2. Mark this day as regularized in the attendance table
    UPDATE attendance 
    SET is_regularized = 1 
    WHERE employee_id = p_employee_id AND date = p_date;

    -- 3. Count total regularized instances for this employee in the same month
    -- We only count records that are either Late or Early Leaving AND have been regularized
    SELECT COUNT(*) INTO v_current_month_count
    FROM attendance
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = MONTH(p_date) 
      AND YEAR(date) = YEAR(p_date)
      AND is_regularized = 1
      AND (is_late = 1 OR is_early_leaving = 1);

    -- 4. Re-evaluate deductions for ALL regularized records in this month
    -- Records 1 to N (where N <= v_max_waived) get 0 deduction
    -- Records N+1 onwards get 0.5 deduction
    
    -- Step A: Set 0.00 for the first 3 (ordered by date)
    UPDATE attendance
    SET deduction_days = 0.00
    WHERE attendance_id IN (
        SELECT attendance_id FROM (
            SELECT attendance_id
            FROM attendance
            WHERE employee_id = p_employee_id 
              AND MONTH(date) = MONTH(p_date) 
              AND YEAR(date) = YEAR(p_date)
              AND is_regularized = 1
              AND (is_late = 1 OR is_early_leaving = 1)
            ORDER BY date ASC
            LIMIT v_max_waived
        ) tmp
    );

    -- Step B: Ensure the 4th+ records still have the deduction
    UPDATE attendance
    SET deduction_days = v_deduction_val
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = MONTH(p_date) 
      AND YEAR(date) = YEAR(p_date)
      AND is_regularized = 1
      AND (is_late = 1 OR is_early_leaving = 1)
      AND attendance_id NOT IN (
          SELECT attendance_id FROM (
              SELECT attendance_id
              FROM attendance
              WHERE employee_id = p_employee_id 
                AND MONTH(date) = MONTH(p_date) 
                AND YEAR(date) = YEAR(p_date)
                AND is_regularized = 1
                AND (is_late = 1 OR is_early_leaving = 1)
              ORDER BY date ASC
              LIMIT v_max_waived
          ) tmp2
      );

    SELECT v_current_month_count AS regularized_count_this_month;
END //

DELIMITER ;
