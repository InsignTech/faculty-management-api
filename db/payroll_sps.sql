-- Payroll Stored Procedures

-- 1. sp_run_payroll
-- Calculates draft salary disbursements for all active employees for a given payroll period.
DROP PROCEDURE IF EXISTS sp_run_payroll;
//
CREATE PROCEDURE sp_run_payroll(
    IN p_organization_id INT,
    IN p_period_id INT,
    IN p_prepared_by INT
)
BEGIN
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_status VARCHAR(30);
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_days_in_period INT;
    DECLARE done INT DEFAULT 0;
    
    DECLARE v_emp_id INT;
    DECLARE v_struct_id INT;
    DECLARE v_basic_pay DECIMAL(15,2);
    DECLARE v_hra DECIMAL(15,2);
    DECLARE v_edu_allowance DECIMAL(15,2);
    DECLARE v_spec_allowance DECIMAL(15,2);
    DECLARE v_naac_allowance DECIMAL(15,2);
    DECLARE v_gross_salary DECIMAL(15,2);
    
    DECLARE v_lop_days DECIMAL(5,2);
    DECLARE v_lop_deduction DECIMAL(15,2);
    DECLARE v_payable_amount DECIMAL(15,2);
    
    -- Deductions variables
    DECLARE v_total_deduction DECIMAL(15,2);
    DECLARE v_net_salary DECIMAL(15,2);
    DECLARE v_epf_base DECIMAL(15,2);
    DECLARE v_epf_amount DECIMAL(15,2);
    DECLARE v_esi_base DECIMAL(15,2);
    DECLARE v_esi_amount DECIMAL(15,2);
    DECLARE v_pt_amount DECIMAL(15,2);
    DECLARE v_loan_deduction DECIMAL(15,2);
    DECLARE v_tds_amount DECIMAL(15,2);
    DECLARE v_bus_fee DECIMAL(15,2);
    DECLARE v_json_deductions JSON;
    
    -- Cursor for employees
    DECLARE emp_cursor CURSOR FOR 
        SELECT e.employee_id 
        FROM employee e
        WHERE e.active = 1 AND (p_organization_id IS NULL OR e.organization_id = p_organization_id);
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    
    -- 1. Fetch Period Info
    SELECT start_date, end_date, status, month, year 
    INTO v_start_date, v_end_date, v_status, v_month, v_year
    FROM payroll_period
    WHERE period_id = p_period_id;
    
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payroll period not found';
    END IF;
    
    IF v_status IN ('completed', 'locked') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot run payroll on completed or locked periods';
    END IF;
    
    -- Set period status to processing
    UPDATE payroll_period 
    SET status = 'processing' 
    WHERE period_id = p_period_id;
    
    -- Clean up previous runs for this period
    DELETE FROM salary_disbursement WHERE period_id = p_period_id;
    
    SET v_days_in_period = DATEDIFF(v_end_date, v_start_date) + 1;
    IF v_days_in_period <= 0 THEN
        SET v_days_in_period = 30;
    END IF;
    
    OPEN emp_cursor;
    
    read_loop: LOOP
        FETCH emp_cursor INTO v_emp_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Get active structure for employee
        SET v_struct_id = NULL;
        SELECT structure_id, basic_pay, hra, educational_allowance, special_allowance, naac_allowance, gross_salary
        INTO v_struct_id, v_basic_pay, v_hra, v_edu_allowance, v_spec_allowance, v_naac_allowance, v_gross_salary
        FROM salary_structure
        WHERE employee_id = v_emp_id AND is_current = 1
        LIMIT 1;
        
        -- If no salary structure is defined, skip or create default empty
        IF v_struct_id IS NOT NULL THEN
            -- Calculate LOP days from attendance_daily
            SELECT COALESCE(SUM(deduction_days), 0)
            INTO v_lop_days
            FROM attendance_daily
            WHERE employee_id = v_emp_id AND date BETWEEN v_start_date AND v_end_date;
            
            -- LOP deduction amount
            SET v_lop_deduction = ROUND((v_gross_salary / v_days_in_period) * v_lop_days, 2);
            IF v_lop_deduction > v_gross_salary THEN
                SET v_lop_deduction = v_gross_salary;
            END IF;
            
            SET v_payable_amount = v_gross_salary - v_lop_deduction;
            
            -- EPF Calculation
            SET v_epf_amount = 0;
            -- Check if EPF is configured and applicable for employee
            IF NOT EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'EPF' AND edc.is_applicable = 0) 
               AND EXISTS (SELECT 1 FROM deduction_rule_master WHERE deduction_code = 'EPF' AND is_active = 1) THEN
               
                -- Base is basic_pay (adjusted for LOP pro-rata)
                SET v_epf_base = ROUND(v_basic_pay * (1 - (v_lop_days / v_days_in_period)), 2);
                -- Apply wage ceiling
                IF v_epf_base > 15000.00 THEN
                    SET v_epf_base = 15000.00;
                END IF;
                SET v_epf_amount = ROUND(v_epf_base * 0.12, 2);
            END IF;
            
            -- Apply custom overrides if set in employee_deduction_config
            SELECT COALESCE(edc.override_amount, v_epf_amount)
            INTO v_epf_amount
            FROM employee_deduction_config edc
            JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
            WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'EPF' AND edc.is_applicable = 1
            LIMIT 1;
            
            -- ESI Calculation
            SET v_esi_amount = 0;
            IF NOT EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'ESI' AND edc.is_applicable = 0)
               AND EXISTS (SELECT 1 FROM deduction_rule_master WHERE deduction_code = 'ESI' AND is_active = 1) THEN
                
                -- Skip if gross > 21000
                IF v_payable_amount <= 21000.00 THEN
                    SET v_esi_base = v_payable_amount;
                    SET v_esi_amount = ROUND(v_esi_base * 0.0075, 2);
                END IF;
            END IF;
            
            SELECT COALESCE(edc.override_amount, v_esi_amount)
            INTO v_esi_amount
            FROM employee_deduction_config edc
            JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
            WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'ESI' AND edc.is_applicable = 1
            LIMIT 1;
            
            -- TDS Calculation
            SET v_tds_amount = 0;
            SELECT COALESCE(tds_override_amount, 0)
            INTO v_tds_amount
            FROM employee_tds_config
            WHERE employee_id = v_emp_id AND financial_year = CONCAT(v_year, '-', v_year+1)
            LIMIT 1;
            
            -- Profession Tax (Slabs)
            SET v_pt_amount = 0;
            SELECT COALESCE(monthly_tax, 0)
            INTO v_pt_amount
            FROM profession_tax_slab
            WHERE v_payable_amount >= min_salary AND (max_salary IS NULL OR v_payable_amount <= max_salary)
              AND (effective_to IS NULL OR effective_to >= v_start_date)
            ORDER BY min_salary DESC
            LIMIT 1;
            
            -- Loan / Salary Advance Deduction
            SET v_loan_deduction = 0;
            SELECT COALESCE(SUM(LEAST(monthly_deduction, balance_amount)), 0)
            INTO v_loan_deduction
            FROM employee_loan
            WHERE employee_id = v_emp_id AND status = 'active' AND balance_amount > 0
              AND (deduction_start_year < v_year OR (deduction_start_year = v_year AND v_period_id >= deduction_start_month));
              
            -- Bus Fee or other custom deductions
            SET v_bus_fee = 0;
            SELECT COALESCE(edc.override_amount, drm.fixed_amount, 0)
            INTO v_bus_fee
            FROM employee_deduction_config edc
            JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
            WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'BUS_FEE' AND edc.is_applicable = 1
            LIMIT 1;
            
            -- Total Deductions
            SET v_total_deduction = v_epf_amount + v_esi_amount + v_tds_amount + v_pt_amount + v_loan_deduction + v_bus_fee;
            
            SET v_net_salary = v_payable_amount - v_total_deduction;
            IF v_net_salary < 0 THEN
                SET v_net_salary = 0;
            END IF;
            
            -- Construct JSON deductions
            SET v_json_deductions = JSON_OBJECT(
                'EPF', v_epf_amount,
                'ESI', v_esi_amount,
                'TDS', v_tds_amount,
                'ProfessionTax', v_pt_amount,
                'LoanEMI', v_loan_deduction,
                'BusFee', v_bus_fee
            );
            
            -- Insert into salary_disbursement
            INSERT INTO salary_disbursement (
                employee_id, structure_id, period_id,
                basic_pay, hra, educational_allowance, special_allowance, naac_allowance, gross_salary,
                lop_days, payable_amount,
                deductions_json, total_deduction, net_salary,
                status, prepared_by, prepared_on
            ) VALUES (
                v_emp_id, v_struct_id, p_period_id,
                v_basic_pay, v_hra, v_edu_allowance, v_spec_allowance, v_naac_allowance, v_gross_salary,
                v_lop_days, v_payable_amount,
                v_json_deductions, v_total_deduction, v_net_salary,
                'draft', p_prepared_by, NOW()
            );
            
            -- Insert approval log
            INSERT INTO payroll_approval_log (
                disbursement_id, period_id, action, action_by, action_on, remarks, previous_status, new_status
            ) VALUES (
                LAST_INSERT_ID(), p_period_id, 'prepared', p_prepared_by, NOW(), 'Payroll run draft calculated', NULL, 'draft'
            );
            
        END IF;
    END LOOP;
    
    CLOSE emp_cursor;
    
    SELECT COUNT(*) AS processed_count FROM salary_disbursement WHERE period_id = p_period_id;
END;
//

-- 2. sp_action_payroll_period
-- Actions status change for a payroll period (submit, verify, approve, pay, reject) and logs it.
DROP PROCEDURE IF EXISTS sp_action_payroll_period;
//
CREATE PROCEDURE sp_action_payroll_period(
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
END;
//
