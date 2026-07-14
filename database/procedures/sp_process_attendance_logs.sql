DROP PROCEDURE IF EXISTS `sp_process_attendance_logs`;

DELIMITER ;;
CREATE PROCEDURE `sp_process_attendance_logs`(
    IN p_date DATE
)
BEGIN
    DECLARE v_grace_in TIME;
    DECLARE v_early_out TIME;
    DECLARE v_deduction_amount DECIMAL(3,2);
    
    -- Load settings
    SELECT setting_value INTO v_grace_in FROM attendance_settings WHERE setting_key = 'grace_in_time';
    SELECT setting_value INTO v_early_out FROM attendance_settings WHERE setting_key = 'early_out_threshold';
    SELECT CAST(setting_value AS DECIMAL(3,2)) INTO v_deduction_amount FROM attendance_settings WHERE setting_key = 'deduction_amount';

    -- 1. Process Punch-Ins
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_late, deduction_days)
    SELECT 
        adl.employee_id, 
        adl.date, 
        'Present', 
        'Biometric', 
        'PunchIn', 
        'Full Day', 
        MIN(adl.time),
        IF(MIN(adl.time) > v_grace_in, 1, 0),
        IF(MIN(adl.time) > v_grace_in, v_deduction_amount, 0.00)
    FROM attendance_detail_log adl
    INNER JOIN employee e ON adl.employee_id = e.employee_id
    WHERE adl.date = p_date AND e.active = 1
    GROUP BY adl.employee_id, adl.date
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_late = VALUES(is_late),
        deduction_days = VALUES(deduction_days),
        status = 'Present';

    -- 2. Process Punch-Outs
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_early_leaving, deduction_days)
    SELECT 
        adl.employee_id, 
        adl.date, 
        'Present', 
        'Biometric', 
        'PunchOut', 
        'Full Day', 
        MAX(adl.time),
        IF(MAX(adl.time) < v_early_out, 1, 0),
        IF(MAX(adl.time) < v_early_out, v_deduction_amount, 0.00)
    FROM attendance_detail_log adl
    INNER JOIN employee e ON adl.employee_id = e.employee_id
    WHERE adl.date = p_date AND e.active = 1
    GROUP BY adl.employee_id, adl.date
    HAVING COUNT(*) > 1
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_early_leaving = VALUES(is_early_leaving),
        deduction_days = GREATEST(deduction_days, VALUES(deduction_days)),
        status = 'Present';
        
    SELECT ROW_COUNT() AS processed_rows;
END ;;
DELIMITER ;
