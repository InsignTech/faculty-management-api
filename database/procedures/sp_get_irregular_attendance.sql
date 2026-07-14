DROP PROCEDURE IF EXISTS `sp_get_irregular_attendance`;

DELIMITER ;;
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
END ;;
DELIMITER ;
