DROP PROCEDURE IF EXISTS `sp_get_attendance_summary`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_attendance_summary`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        SUM(CASE 
            WHEN UPPER(status) = 'PRESENT' AND shift_type = 'FullDay' THEN 1.0
            WHEN UPPER(status) = 'PRESENT' AND shift_type IN ('FirstHalf', 'SecondHalf') THEN 0.5
            ELSE 0.0 
        END) AS present_count,
        SUM(CASE 
            WHEN UPPER(status) = 'ABSENT' AND shift_type = 'FullDay' THEN 1.0
            WHEN UPPER(status) = 'ABSENT' AND shift_type IN ('FirstHalf', 'SecondHalf') THEN 0.5
            ELSE 0.0 
        END) AS absent_count,
        SUM(is_late) AS late_count,
        SUM(is_early_leaving) AS early_leaving_count,
        SUM(CASE 
            WHEN UPPER(status) = 'REGULARIZED' AND shift_type = 'FullDay' THEN 1.0
            WHEN UPPER(status) = 'REGULARIZED' AND shift_type IN ('FirstHalf', 'SecondHalf') THEN 0.5
            ELSE 0.0 
        END) AS regularized_count,
        SUM(CASE 
            WHEN UPPER(status) = 'ONDUTY' AND shift_type = 'FullDay' THEN 1.0
            WHEN UPPER(status) = 'ONDUTY' AND shift_type IN ('FirstHalf', 'SecondHalf') THEN 0.5
            ELSE 0.0 
        END) AS onduty_count,
        SUM(CASE 
            WHEN UPPER(status) = 'LEAVE' AND shift_type = 'FullDay' THEN 1.0
            WHEN UPPER(status) = 'LEAVE' AND shift_type IN ('FirstHalf', 'SecondHalf') THEN 0.5
            ELSE 0.0 
        END) AS leave_days,
        SUM(deduction_days) AS total_deductions
    FROM attendance
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year;
END ;;
DELIMITER ;
