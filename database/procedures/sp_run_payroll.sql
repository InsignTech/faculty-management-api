DROP PROCEDURE IF EXISTS `sp_run_payroll`;

DELIMITER ;;
CREATE PROCEDURE `sp_run_payroll`(
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
    DECLARE v_attendance_count INT;
    DECLARE v_temp_date DATE;
    DECLARE v_weekend_holiday_count INT;
    
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
    DECLARE v_epf_rule_basis VARCHAR(50);
    DECLARE v_epf_rule_rate DECIMAL(10,4);
    DECLARE v_esi_rule_basis VARCHAR(50);
    DECLARE v_esi_rule_rate DECIMAL(10,4);
    
    DECLARE v_epf_rule_months VARCHAR(100);
    DECLARE v_epf_rule_multiplier INT;
    DECLARE v_esi_rule_months VARCHAR(100);
    DECLARE v_esi_rule_multiplier INT;
    DECLARE v_tds_rule_months VARCHAR(100);
    DECLARE v_tds_rule_multiplier INT;
    DECLARE v_pt_rule_months VARCHAR(100);
    DECLARE v_pt_rule_multiplier INT;
    DECLARE v_bus_fee_rule_months VARCHAR(100);
    DECLARE v_bus_fee_rule_multiplier INT;
    
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
    
    SET v_days_in_period = 30;
    
    OPEN emp_cursor;
    
    read_loop: LOOP
        FETCH emp_cursor INTO v_emp_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Get active structure for employee
        SET v_struct_id = NULL;
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
            SELECT structure_id, basic_pay, hra, educational_allowance, special_allowance, naac_allowance, gross_salary
            INTO v_struct_id, v_basic_pay, v_hra, v_edu_allowance, v_spec_allowance, v_naac_allowance, v_gross_salary
            FROM salary_structure
            WHERE employee_id = v_emp_id AND is_current = 1
            LIMIT 1;
        END;
        
        -- If no salary structure is defined, skip or create default empty
        IF v_struct_id IS NOT NULL THEN
            -- Initialize/reset calculation variables for each employee
            SET v_epf_base = 0;
            SET v_epf_rule_rate = 12.0;
            SET v_epf_rule_basis = 'basic_pay';
            SET v_esi_base = 0;
            SET v_esi_rule_rate = 0.75;
            SET v_esi_rule_basis = 'gross_salary';
            SET v_tds_amount = 0;
            SET v_pt_amount = 0;
            SET v_loan_deduction = 0;
            SET v_bus_fee = 0;

            -- Check if there are any attendance records for this period
            SET v_attendance_count = 0;
            SELECT COUNT(*) INTO v_attendance_count
            FROM attendance_daily
            WHERE employee_id = v_emp_id AND date BETWEEN v_start_date AND v_end_date;

            IF v_attendance_count = 0 THEN
                -- No records at all. Calculate all working days as LOP (excluding Sundays and holidays)
                SET v_weekend_holiday_count = 0;
                SET v_temp_date = v_start_date;
                WHILE v_temp_date <= v_end_date DO
                    IF DAYOFWEEK(v_temp_date) = 1 OR EXISTS (
                        SELECT 1 FROM holiday_master
                        WHERE is_active = 1
                          AND (employee_id = -1 OR employee_id = v_emp_id)
                          AND v_temp_date BETWEEN holiday_start_date AND holiday_end_date
                    ) THEN
                        SET v_weekend_holiday_count = v_weekend_holiday_count + 1;
                    END IF;
                    SET v_temp_date = DATE_ADD(v_temp_date, INTERVAL 1 DAY);
                END WHILE;
                SET v_lop_days = v_days_in_period - v_weekend_holiday_count;
            ELSE
                -- Calculate LOP days from attendance_daily
                SELECT COALESCE(SUM(deduction_days), 0)
                INTO v_lop_days
                FROM attendance_daily
                WHERE employee_id = v_emp_id AND date BETWEEN v_start_date AND v_end_date;
            END IF;
            
            -- LOP deduction amount
            SET v_lop_deduction = ROUND((v_gross_salary / v_days_in_period) * v_lop_days, 2);
            IF v_lop_deduction > v_gross_salary THEN
                SET v_lop_deduction = v_gross_salary;
            END IF;
            
            SET v_payable_amount = v_gross_salary - v_lop_deduction;
            
            -- EPF Calculation
            SET v_epf_amount = 0;
            -- Check if EPF is configured and applicable for employee (must exist and be active)
            IF EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'EPF' AND edc.is_applicable = 1) 
               AND EXISTS (SELECT 1 FROM deduction_rule_master WHERE deduction_code = 'EPF' AND is_active = 1) THEN
                
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT COALESCE(calc_basis, 'basic_pay'), COALESCE(rate, 12.0), applicable_months, COALESCE(projection_multiplier, 1)
                    INTO v_epf_rule_basis, v_epf_rule_rate, v_epf_rule_months, v_epf_rule_multiplier
                    FROM deduction_rule_master
                    WHERE deduction_code = 'EPF' AND is_active = 1;
                END;
               
                IF v_epf_rule_months IS NULL OR FIND_IN_SET(v_month, v_epf_rule_months) > 0 THEN
                    -- Base calculation based on dynamic calc_basis
                    IF v_epf_rule_basis = 'gross_salary' THEN
                        SET v_epf_base = ROUND(v_gross_salary * (1 - (v_lop_days / v_days_in_period)), 2);
                    ELSE
                        SET v_epf_base = ROUND(v_basic_pay * (1 - (v_lop_days / v_days_in_period)), 2);
                    END IF;
                    -- Apply wage ceiling
                    IF v_epf_base > 15000.00 THEN
                        SET v_epf_base = 15000.00;
                    END IF;
                    SET v_epf_amount = ROUND(v_epf_base * (v_epf_rule_rate / 100), 2);
                    
                    -- Apply custom overrides if set in employee_deduction_config
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT edc.override_amount
                        INTO v_epf_amount
                        FROM employee_deduction_config edc
                        JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                        WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'EPF' AND edc.is_applicable = 1 AND edc.override_amount IS NOT NULL
                        LIMIT 1;
                    END;
                END IF;
            END IF;
            
            -- ESI Calculation
            SET v_esi_amount = 0;
            IF EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'ESI' AND edc.is_applicable = 1)
               AND EXISTS (SELECT 1 FROM deduction_rule_master WHERE deduction_code = 'ESI' AND is_active = 1) THEN
                
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT COALESCE(calc_basis, 'gross_salary'), COALESCE(rate, 0.75), applicable_months, COALESCE(projection_multiplier, 1)
                    INTO v_esi_rule_basis, v_esi_rule_rate, v_esi_rule_months, v_esi_rule_multiplier
                    FROM deduction_rule_master
                    WHERE deduction_code = 'ESI' AND is_active = 1;
                END;

                IF v_esi_rule_months IS NULL OR FIND_IN_SET(v_month, v_esi_rule_months) > 0 THEN
                    -- Base calculation based on dynamic calc_basis
                    IF v_esi_rule_basis = 'basic_pay' THEN
                        SET v_esi_base = ROUND(v_basic_pay * (1 - (v_lop_days / v_days_in_period)), 2);
                    ELSE
                        SET v_esi_base = v_payable_amount;
                    END IF;
                    
                    -- Skip if base > 21000
                    IF v_esi_base <= 21000.00 THEN
                        SET v_esi_amount = ROUND(v_esi_base * (v_esi_rule_rate / 100), 2);
                    END IF;
                    
                    -- Apply custom overrides if set in employee_deduction_config
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT edc.override_amount
                        INTO v_esi_amount
                        FROM employee_deduction_config edc
                        JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                        WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'ESI' AND edc.is_applicable = 1 AND edc.override_amount IS NOT NULL
                        LIMIT 1;
                    END;
                END IF;
            END IF;
            
            -- TDS Calculation
            SET v_tds_amount = 0;
            IF EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'TDS' AND edc.is_applicable = 1) THEN
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT applicable_months, COALESCE(projection_multiplier, 1)
                    INTO v_tds_rule_months, v_tds_rule_multiplier
                    FROM deduction_rule_master
                    WHERE deduction_code = 'TDS' AND is_active = 1;
                END;

                IF v_tds_rule_months IS NULL OR FIND_IN_SET(v_month, v_tds_rule_months) > 0 THEN
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT COALESCE(tds_override_amount, 0)
                        INTO v_tds_amount
                        FROM employee_tds_config
                        WHERE employee_id = v_emp_id AND financial_year = CONCAT(v_year, '-', v_year+1)
                        LIMIT 1;
                    END;
                    
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT edc.override_amount
                        INTO v_tds_amount
                        FROM employee_deduction_config edc
                        JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                        WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'TDS' AND edc.is_applicable = 1 AND edc.override_amount IS NOT NULL
                        LIMIT 1;
                    END;
                END IF;
            END IF;
            
            -- Profession Tax (Slabs)
            SET v_pt_amount = 0;
            IF EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'PT' AND edc.is_applicable = 1) THEN
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT applicable_months, COALESCE(projection_multiplier, 1)
                    INTO v_pt_rule_months, v_pt_rule_multiplier
                    FROM deduction_rule_master
                    WHERE deduction_code = 'PT' AND is_active = 1;
                END;

                IF v_pt_rule_months IS NULL OR FIND_IN_SET(v_month, v_pt_rule_months) > 0 THEN
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT COALESCE(monthly_tax, 0)
                        INTO v_pt_amount
                        FROM profession_tax_slab
                        WHERE (v_payable_amount * v_pt_rule_multiplier) >= min_salary AND (max_salary IS NULL OR (v_payable_amount * v_pt_rule_multiplier) <= max_salary)
                          AND (effective_to IS NULL OR effective_to >= v_start_date)
                        ORDER BY min_salary DESC
                        LIMIT 1;
                    END;
                    
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT edc.override_amount
                        INTO v_pt_amount
                        FROM employee_deduction_config edc
                        JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                        WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'PT' AND edc.is_applicable = 1 AND edc.override_amount IS NOT NULL
                        LIMIT 1;
                    END;
                END IF;
            END IF;
            
            -- Loan / Salary Advance Deduction
            BEGIN
                DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                SELECT COALESCE(SUM(LEAST(monthly_deduction, balance_amount)), 0)
                INTO v_loan_deduction
                FROM employee_loan
                WHERE employee_id = v_emp_id AND status = 'active' AND balance_amount > 0
                  AND (deduction_start_year < v_year OR (deduction_start_year = v_year AND v_month >= deduction_start_month));
            END;
              
            -- Bus Fee or other custom deductions
            SET v_bus_fee = 0;
            BEGIN
                DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                SELECT applicable_months, COALESCE(projection_multiplier, 1)
                INTO v_bus_fee_rule_months, v_bus_fee_rule_multiplier
                FROM deduction_rule_master
                WHERE deduction_code = 'BUS_FEE' AND is_active = 1;
            END;

            IF v_bus_fee_rule_months IS NULL OR FIND_IN_SET(v_month, v_bus_fee_rule_months) > 0 THEN
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT COALESCE(edc.override_amount, drm.fixed_amount, 0)
                    INTO v_bus_fee
                    FROM employee_deduction_config edc
                    JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                    WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'BUS_FEE' AND edc.is_applicable = 1
                    LIMIT 1;
                END;
            END IF;
            
            -- Total Deductions
            SET v_total_deduction = v_epf_amount + v_esi_amount + v_tds_amount + v_pt_amount + v_loan_deduction + v_bus_fee;
            
            SET v_net_salary = v_payable_amount - v_total_deduction;
            IF v_net_salary < 0 THEN
                SET v_net_salary = 0;
            END IF;
            
            -- Construct JSON deductions (with all calculation bases and metadata)
            SET v_json_deductions = JSON_OBJECT(
                'EPF', v_epf_amount,
                'EPF_base', v_epf_base,
                'EPF_rate', v_epf_rule_rate,
                'ESI', v_esi_amount,
                'ESI_base', v_esi_base,
                'ESI_rate', v_esi_rule_rate,
                'TDS', v_tds_amount,
                'ProfessionTax', v_pt_amount,
                'LoanEMI', v_loan_deduction,
                'BusFee', v_bus_fee,
                'LOP_days', v_lop_days,
                'LOP_deduction', v_lop_deduction,
                'Gross_salary', v_gross_salary,
                'Basic_pay', v_basic_pay,
                'Payable_amount', v_payable_amount,
                'Days_in_period', v_days_in_period,
                'isEPFApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'EPF' AND edc.is_applicable = 1) AND (v_epf_rule_months IS NULL OR FIND_IN_SET(v_month, v_epf_rule_months) > 0) THEN 1 ELSE 0 END,
                'isESIApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'ESI' AND edc.is_applicable = 1) AND (v_esi_rule_months IS NULL OR FIND_IN_SET(v_month, v_esi_rule_months) > 0) THEN 1 ELSE 0 END,
                'isTDSApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'TDS' AND edc.is_applicable = 1) AND (v_tds_rule_months IS NULL OR FIND_IN_SET(v_month, v_tds_rule_months) > 0) THEN 1 ELSE 0 END,
                'isPTApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'PT' AND edc.is_applicable = 1) AND (v_pt_rule_months IS NULL OR FIND_IN_SET(v_month, v_pt_rule_months) > 0) THEN 1 ELSE 0 END,
                'isBusFeeApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'BUS_FEE' AND edc.is_applicable = 1) AND (v_bus_fee_rule_months IS NULL OR FIND_IN_SET(v_month, v_bus_fee_rule_months) > 0) THEN 1 ELSE 0 END
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
END ;;
DELIMITER ;
