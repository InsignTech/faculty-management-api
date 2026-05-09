USE `staffdesk`;

DROP PROCEDURE IF EXISTS `sp_get_irregular_attendance`;

DELIMITER $$

CREATE PROCEDURE `sp_get_irregular_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        ad.attendance_id,
        ad.employee_id,
        ad.date,
        ad.first_in_time,
        ad.last_out_time,
        ad.worked_mins,
        ad.shift_type,
        ad.status,
        ad.deduction_days,
        CASE
            -- FULL DAY ABSENT
            WHEN ad.deduction_days = 1.0 AND ad.status = 'Absent' THEN 'Full Day Missing'
            
            -- INCOMPLETE PUNCH (Mandatory 1.0 Deduction as per your policy)
            WHEN ad.deduction_days = 1.0 AND (ad.first_in_time = ad.last_out_time OR ad.first_in_time IS NULL OR ad.last_out_time IS NULL)
                THEN 'Incomplete Punch'

            -- HALF DAY ABSENT / LEAVE
            WHEN ad.deduction_days = 0.5 AND ad.status = 'Absent' AND ad.shift_type = 'FirstHalf' THEN 'Second Half Missing'
            WHEN ad.deduction_days = 0.5 AND ad.status = 'Absent' AND ad.shift_type = 'SecondHalf' THEN 'First Half Missing'
            WHEN ad.deduction_days = 0.5 AND ad.status = 'Leave' AND ad.shift_type = 'FirstHalf' THEN 'Second Half Missing'
            WHEN ad.deduction_days = 0.5 AND ad.status = 'Leave' AND ad.shift_type = 'SecondHalf' THEN 'First Half Missing'
        END AS final_status,
        CASE
            -- FULL DAY ABSENT
            WHEN ad.deduction_days = 1.0 AND ad.status = 'Absent' THEN 'FullDay'
            
            -- INCOMPLETE PUNCH (Mandatory 1.0 Deduction as per your policy)
            WHEN ad.deduction_days = 1.0 AND (ad.first_in_time = ad.last_out_time OR ad.first_in_time IS NULL OR ad.last_out_time IS NULL)
                THEN 'FullDay'

            -- HALF DAY ABSENT / LEAVE
            WHEN ad.deduction_days = 0.5 AND ad.status = 'Absent' AND ad.shift_type = 'FirstHalf' THEN 'SecondHalf'
            WHEN ad.deduction_days = 0.5 AND ad.status = 'Absent' AND ad.shift_type = 'SecondHalf' THEN 'FirstHalf'
            WHEN ad.deduction_days = 0.5 AND ad.status = 'Leave' AND ad.shift_type = 'FirstHalf' THEN 'SecondHalf'
            WHEN ad.deduction_days = 0.5 AND ad.status = 'Leave' AND ad.shift_type = 'SecondHalf' THEN 'FirstHalf'

        END
        AS regularization_shift_type
    FROM attendance_daily ad
    WHERE ad.employee_id = p_employee_id 
      AND MONTH(ad.date) = p_month 
      AND YEAR(ad.date) = p_year
      AND (ad.deduction_days > 0 OR ad.is_late = 1 OR ad.is_early_leaving = 1)
      AND ad.is_regularized = 0
      
      -- Exclude Weekends and Public Holidays based on status (fallback)
      AND ad.status NOT IN ('WeekEnd', 'Public Holiday', 'Exceptional Holiday', 'Vacation')
      
      -- Exclude dates that fall entirely under an approved full-day leave
      AND NOT EXISTS (
          SELECT 1 
          FROM leave_requests lr 
          WHERE lr.employee_id = ad.employee_id 
            AND lr.status = 'Approved' 
            AND ad.date BETWEEN lr.start_date AND lr.end_date
            AND lr.leave_half_type = 'FullDay'
      )
      
      -- Exclude dates that are actively configured as holidays
      AND NOT EXISTS (
          SELECT 1 
          FROM holiday_master hm 
          WHERE ad.date BETWEEN hm.holiday_start_date AND hm.holiday_end_date
            AND hm.is_active = 1
            AND (hm.employee_id IS NULL OR hm.employee_id = 0 OR hm.employee_id = ad.employee_id)
      )
      
    ORDER BY ad.date DESC;
END$$

DELIMITER ;
