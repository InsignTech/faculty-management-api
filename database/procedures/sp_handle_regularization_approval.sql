DROP PROCEDURE IF EXISTS `sp_handle_regularization_approval`;

DELIMITER ;;
CREATE PROCEDURE `sp_handle_regularization_approval`(
    IN p_adjustment_id INT,
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_date DATE;
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_approved_count INT;
    
    
    SELECT employee_id, date INTO v_emp_id, v_date FROM attendance_adjustments WHERE adjustment_id = p_adjustment_id;
    SET v_month = MONTH(v_date);
    SET v_year = YEAR(v_date);
    
    
    SELECT COUNT(*) INTO v_approved_count 
    FROM attendance_adjustments 
    WHERE employee_id = v_emp_id 
      AND MONTH(date) = v_month 
      AND YEAR(date) = v_year 
      AND status = 'Approved'
      AND type = 'Regularization';
      
    
    UPDATE attendance_adjustments 
    SET status = 'Approved', 
        approved_by_id = p_approver_id, 
        approved_on = NOW(),
        remarks = p_remarks
    WHERE adjustment_id = p_adjustment_id;
    
    
    IF v_approved_count < 3 THEN
        UPDATE attendance 
        SET is_regularized = 1, deduction_days = 0.00 
        WHERE employee_id = v_emp_id AND date = v_date;
    ELSE
        UPDATE attendance 
        SET is_regularized = 1, deduction_days = 0.50 
        WHERE employee_id = v_emp_id AND date = v_date;
    END IF;
    
    SELECT v_approved_count + 1 AS monthly_approved_count;
END ;;
DELIMITER ;
