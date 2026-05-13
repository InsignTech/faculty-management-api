DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_get_irregular_attendance`$$

CREATE PROCEDURE `sp_get_irregular_attendance`(
    IN p_employee_id INT,
    IN p_month       INT,
    IN p_year        INT
)
BEGIN
    SELECT 
        ad.date,
        CASE 
            -- Case 1: Has a partial leave, but the other half is missing
            WHEN ad.is_leave = 1 AND ad.leave_shift_type = 'SecondHalf' AND ad.first_in_time IS NULL 
                 THEN CONCAT('1st Half Missing (', ad.is_leave_type, ')')
            WHEN ad.is_leave = 1 AND ad.leave_shift_type = 'FirstHalf' AND ad.last_out_time IS NULL 
                 THEN CONCAT('2nd Half Missing (', ad.is_leave_type, ')')
            
            -- Case 2: Late and Early
            WHEN ad.is_late = 1 AND ad.is_early_leaving = 1 
                 THEN 'Late In & Early Out'
            WHEN ad.is_late = 1 
                 THEN 'Late Arrival'
            WHEN ad.is_early_leaving = 1 
                 THEN 'Early Leaving'

            -- Case 3: Marked Present (via leave or auto-process) but punches are actually missing
            WHEN ad.first_in_time IS NULL AND ad.last_out_time IS NULL AND ad.is_leave = 0 
                 THEN 'Full Day Missing'
            WHEN ad.first_in_time IS NULL 
                 THEN 'Missing Punch (In)'
            WHEN ad.last_out_time IS NULL 
                 THEN 'Missing Punch (Out)'
            
            ELSE 'Irregular Day'
        END as irregularity_reason,
        ad.is_regularized,
        ad.status as final_status,
        ad.regularization_shift_type,
        ad.deduction_days
    FROM attendance_daily ad
    WHERE ad.employee_id = p_employee_id
      AND MONTH(ad.date) = p_month
      AND YEAR(ad.date) = p_year
      -- Modified: Show if NOT regularized OR if it's only partially regularized with remaining deduction
      AND (ad.is_regularized = 0 OR (ad.regularization_shift_type != 'FullDay' AND ad.deduction_days > 0))
      
      -- Exclude Weekends and Holidays
      AND ad.status NOT IN ('WeekEnd', 'Public Holiday', 'Weekly Off')
      
      -- Show if any irregularity persists:
      AND (
          (ad.first_in_time IS NULL AND ad.last_out_time IS NULL AND (ad.is_leave = 0 OR ad.leave_shift_type != 'FullDay'))
          OR
          (ad.first_in_time IS NULL OR ad.last_out_time IS NULL)
          OR
          ad.is_late = 1 OR ad.is_early_leaving = 1
          OR
          ad.deduction_days > 0
      )
    ORDER BY ad.date DESC;
END$$

DELIMITER ;
