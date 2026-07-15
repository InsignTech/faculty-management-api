DROP PROCEDURE IF EXISTS `sp_get_attendance_summary`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_attendance_summary`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        COUNT(CASE WHEN UPPER(status) = 'PRESENT' THEN 1 END) AS present_count,
        COUNT(CASE WHEN UPPER(status) = 'ABSENT' THEN 1 END) AS absent_count,
        SUM(is_late) AS late_count,
        SUM(is_early_leaving) AS early_leaving_count,
        SUM(CASE WHEN regularization_shift_type IS NOT NULL THEN 1 ELSE 0 END) AS regularized_count,
        SUM(CASE WHEN onduty_shift_type IS NOT NULL THEN 1 ELSE 0 END) AS onduty_count,
        SUM(CASE 
            WHEN is_leave = 1 AND (leave_shift_type = 'FullDay' OR leave_shift_type IS NULL) THEN 1.0
            WHEN is_leave = 1 AND (leave_shift_type = 'FirstHalf' OR leave_shift_type = 'SecondHalf') THEN 0.5
            ELSE 0 
        END) AS leave_days,
        SUM(deduction_days) AS total_deductions
    FROM attendance_daily
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year;
END ;;
DELIMITER ;
