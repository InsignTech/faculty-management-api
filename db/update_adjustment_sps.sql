USE `staffdesk`;

DELIMITER //

-- Updated: Get Adjustment History for Employee with Filtering
DROP PROCEDURE IF EXISTS `sp_get_employee_adjustments` //
CREATE PROCEDURE `sp_get_employee_adjustments`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        aj.*,
        e.employee_name as approver_name
    FROM attendance_adjustments aj
    LEFT JOIN employee e ON aj.approved_by_id = e.employee_id
    WHERE aj.employee_id = p_employee_id
      AND (p_month IS NULL OR MONTH(aj.date) = p_month)
      AND (p_year IS NULL OR YEAR(aj.date) = p_year)
    ORDER BY aj.requested_on DESC;
END //

-- New/Updated: Unified Adjustment Approval Logic
DROP PROCEDURE IF EXISTS `sp_handle_adjustment_approval` //
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
          AND adjustment_id != p_adjustment_id; -- Don't count self
          
        -- Update attendance table based on the rule (first 3 are free)
        -- If count < 3, then this current one is the 1st, 2nd, or 3rd.
        IF v_approved_count < 3 THEN
            UPDATE attendance 
            SET is_regularized = 1, deduction_days = 0.00, status = 'Present'
            WHERE employee_id = v_emp_id AND date = v_date;
        ELSE
            UPDATE attendance 
            SET is_regularized = 1, deduction_days = 0.50, status = 'Present'
            WHERE employee_id = v_emp_id AND date = v_date;
        END IF;
    
    ELSEIF v_type = 'OnDuty' THEN
        -- Ensure employee is present for both shifts on this date
        -- In our system, attendance records are per punch type (In/Out)
        
        -- Handle PunchIn
        INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_regularized, deduction_days)
        VALUES (v_emp_id, v_date, 'Present', 'Onduty', 'PunchIn', 'Full Day', '09:00:00', 1, 0.00)
        ON DUPLICATE KEY UPDATE 
            status = 'Present', punch_type = 'Onduty', punch_time = '09:00:00', is_regularized = 1, deduction_days = 0.00;
            
        -- Handle PunchOut
        INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_regularized, deduction_days)
        VALUES (v_emp_id, v_date, 'Present', 'Onduty', 'PunchOut', 'Full Day', '17:00:00', 1, 0.00)
        ON DUPLICATE KEY UPDATE 
            status = 'Present', punch_type = 'Onduty', punch_time = '17:00:00', is_regularized = 1, deduction_days = 0.00;
            
    END IF;
    
    SELECT 'Success' as result;
END //

DELIMITER ;
