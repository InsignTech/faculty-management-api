DROP PROCEDURE IF EXISTS `sp_action_payroll_period`;

DELIMITER ;;
CREATE PROCEDURE `sp_action_payroll_period`(
    IN p_period_id INT,
    IN p_action VARCHAR(30), -- 'submitted', 'verified', 'approved', 'paid', 'rejected'
    IN p_action_by INT,
    IN p_remarks VARCHAR(500)
)
BEGIN
    DECLARE v_current_status VARCHAR(30);
    DECLARE v_new_status VARCHAR(30);
    
    SELECT status INTO v_current_status FROM payroll_period WHERE period_id = p_period_id;
    
    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payroll period not found';
    END IF;
    
    -- Map period state machine
    IF p_action = 'submitted' THEN
        SET v_new_status = 'processing';
    ELSEIF p_action = 'verified' THEN
        SET v_new_status = 'processing';
    ELSEIF p_action = 'approved' THEN
        SET v_new_status = 'completed';
    ELSEIF p_action = 'paid' THEN
        SET v_new_status = 'locked';
    ELSEIF p_action = 'rejected' THEN
        SET v_new_status = 'draft';
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid action specified';
    END IF;
    
    -- Update period status
    UPDATE payroll_period SET status = v_new_status WHERE period_id = p_period_id;
    
    -- Update disbursement records status to match
    UPDATE salary_disbursement 
    SET status = p_action,
        prepared_by = CASE WHEN p_action = 'submitted' THEN p_action_by ELSE prepared_by END,
        prepared_on = CASE WHEN p_action = 'submitted' THEN NOW() ELSE prepared_on END,
        verified_by = CASE WHEN p_action = 'verified' THEN p_action_by ELSE verified_by END,
        verified_on = CASE WHEN p_action = 'verified' THEN NOW() ELSE verified_on END,
        verified_remarks = CASE WHEN p_action = 'verified' THEN p_remarks ELSE verified_remarks END,
        approved_by = CASE WHEN p_action = 'approved' THEN p_action_by ELSE approved_by END,
        approved_on = CASE WHEN p_action = 'approved' THEN NOW() ELSE approved_on END,
        approved_remarks = CASE WHEN p_action = 'approved' THEN p_remarks ELSE approved_remarks END,
        rejected_by = CASE WHEN p_action = 'rejected' THEN p_action_by ELSE rejected_by END,
        rejected_on = CASE WHEN p_action = 'rejected' THEN NOW() ELSE rejected_on END,
        rejected_remarks = CASE WHEN p_action = 'rejected' THEN p_remarks ELSE rejected_remarks END,
        payment_date = CASE WHEN p_action = 'paid' THEN CURRENT_DATE() ELSE payment_date END,
        remarks = CASE WHEN p_action = 'paid' THEN p_remarks ELSE remarks END
    WHERE period_id = p_period_id;
    
    -- Update loan balances and mark as paid if action is paid
    IF p_action = 'paid' THEN
        -- Loop over disbursements for this period and update loans
        -- We will do a bulk update:
        UPDATE employee_loan el
        JOIN (
            SELECT sd.employee_id, 
                   JSON_UNQUOTE(JSON_EXTRACT(sd.deductions_json, '$.LoanEMI')) AS loan_emi
            FROM salary_disbursement sd
            WHERE sd.period_id = p_period_id
        ) sub ON el.employee_id = sub.employee_id
        SET el.total_paid_amount = el.total_paid_amount + CAST(sub.loan_emi AS DECIMAL(15,2)),
            el.status = CASE WHEN el.total_paid_amount + CAST(sub.loan_emi AS DECIMAL(15,2)) >= el.loan_amount THEN 'closed' ELSE el.status END
        WHERE el.status = 'active' AND CAST(sub.loan_emi AS DECIMAL(15,2)) > 0;
    END IF;
    
    -- Insert into approval logs for tracking
    INSERT INTO payroll_approval_log (
        disbursement_id, period_id, action, action_by, action_on, remarks, previous_status, new_status
    )
    SELECT 
        disbursement_id, p_period_id, p_action, p_action_by, NOW(), p_remarks, v_current_status, p_action
    FROM salary_disbursement
    WHERE period_id = p_period_id;
    
    SELECT ROW_COUNT() AS updated_disbursements;
END ;;
DELIMITER ;
