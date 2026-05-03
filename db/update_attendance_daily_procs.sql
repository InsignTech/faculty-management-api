USE `staffdesk`;

DELIMITER //

-- 1. Update Get Attendance History to use attendance_daily
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
        date,
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
        is_regularized,
        is_regularize_type,
        created_on
    FROM attendance_daily 
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year
    ORDER BY date DESC;
END //

-- 2. Update Attendance Summary to use attendance_daily
DROP PROCEDURE IF EXISTS `sp_get_attendance_summary` //
CREATE PROCEDURE `sp_get_attendance_summary`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        COUNT(DISTINCT CASE WHEN status = 'Present' THEN date END) AS total_days_present,
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_count,
        SUM(CASE WHEN is_early_leaving = 1 THEN 1 ELSE 0 END) AS early_leaving_count,
        SUM(CASE WHEN is_regularized = 1 THEN 1 ELSE 0 END) AS regularized_count,
        SUM(deduction_days) AS total_deductions
    FROM attendance_daily
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year;
END //

DELIMITER ;
