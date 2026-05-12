USE `staffdesk`;

DELIMITER //

-- 1. Update Get Attendance History to include leave fields
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
        is_regularized,
        is_regularize_type,
        regularization_shift_type,
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

-- 2. Update Irregular Attendance to include leave fields
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
        is_leave,
        is_leave_type,
        leave_shift_type,
        CASE
            -- LEAVE
            WHEN is_leave = 1 THEN CONCAT(is_leave_type, ' (', leave_shift_type, ')')

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
      AND (deduction_days > 0 OR is_late = 1 OR is_early_leaving = 1 OR is_leave = 1)
      AND is_regularized = 0
    ORDER BY date DESC;
END //

DELIMITER ;
