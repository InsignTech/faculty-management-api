DROP PROCEDURE IF EXISTS `sp_handle_adjustment_approval`;

DELIMITER ;;
CREATE PROCEDURE `sp_handle_adjustment_approval`(
    IN p_adjustment_id INT,
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_date DATE;
    DECLARE v_type ENUM('Regularization', 'OnDuty');
    DECLARE v_punch_time TIME;
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_approved_count INT;
    
    -- 1. Get adjustment details
    SELECT employee_id, date, type, punch_time 
    INTO v_emp_id, v_date, v_type, v_punch_time 
    FROM attendance_adjustments 
    WHERE adjustment_id = p_adjustment_id;
    
    SET v_month = MONTH(v_date);
    SET v_year = YEAR(v_date);
    
    -- 2. Update status to Approved
    UPDATE attendance_adjustments 
    SET status = 'Approved', 
        approved_by_id = p_approver_id, 
        approved_on = NOW(),
        remarks = CONCAT(COALESCE(remarks, ''), ' | Final Approval: ', p_remarks)
    WHERE adjustment_id = p_adjustment_id;
    
    -- 3. Apply changes to attendance table based on type
    IF v_type = 'Regularization' THEN
        -- Count previous approved regularizations this month
        SELECT COUNT(*) INTO v_approved_count 
        FROM attendance_adjustments 
        WHERE employee_id = v_emp_id 
          AND MONTH(date) = v_month 
          AND YEAR(date) = v_year 
          AND status = 'Approved'
          AND type = 'Regularization'
          AND adjustment_id != p_adjustment_id;
          
        IF v_approved_count < 3 THEN
            UPDATE attendance_daily 
            SET regularization_shift_type = 'FullDay', deduction_days = 0.00, status = 'Present'
            WHERE employee_id = v_emp_id AND date = v_date;
        ELSE
            UPDATE attendance_daily 
            SET regularization_shift_type = 'FullDay', deduction_days = 0.50, status = 'Present'
            WHERE employee_id = v_emp_id AND date = v_date;
        END IF;
    
    ELSEIF v_type = 'OnDuty' THEN
        -- Mark as Present for both shifts
        INSERT INTO attendance_daily (employee_id, date, status, first_in_time, last_out_time, onduty_shift_type, deduction_days)
        VALUES (v_emp_id, v_date, 'Present', '09:00:00', '17:00:00', 'FullDay', 0.00)
        ON DUPLICATE KEY UPDATE 
            status = 'Present', first_in_time = '09:00:00', last_out_time = '17:00:00', onduty_shift_type = 'FullDay', deduction_days = 0.00;
    END IF;
    
    SELECT 'Success' as result;
END ;;
DELIMITER ;
