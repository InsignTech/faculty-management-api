DELIMITER //

DROP PROCEDURE IF EXISTS sp_sync_leave_accrual //

CREATE PROCEDURE sp_sync_leave_accrual(
    IN p_emp_id INT,
    IN p_leave_type VARCHAR(50),
    IN p_month_year VARCHAR(7),
    IN p_target_year INT,
    IN p_target_month INT,
    IN p_credit_amount DECIMAL(10,2),
    IN p_is_dry_run BOOLEAN,
    IN p_start_month INT
)
BEGIN
    DECLARE v_opening_leave DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_leaves_taken DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_last_balance DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_found_last BOOLEAN DEFAULT FALSE;

    -- 1. Find the LATEST available balance BEFORE the target month
    SELECT balance_leave INTO v_last_balance
    FROM employee_leaves
    WHERE emp_id = p_emp_id AND leave_type = p_leave_type
    AND (
        CAST(SUBSTRING_INDEX(month_year, '-', -1) AS UNSIGNED) < p_target_year
        OR (
            CAST(SUBSTRING_INDEX(month_year, '-', -1) AS UNSIGNED) = p_target_year
            AND CAST(SUBSTRING_INDEX(month_year, '-', 1) AS UNSIGNED) < p_target_month
        )
    )
    ORDER BY CAST(SUBSTRING_INDEX(month_year, '-', -1) AS UNSIGNED) DESC, 
             CAST(SUBSTRING_INDEX(month_year, '-', 1) AS UNSIGNED) DESC 
    LIMIT 1;

    IF v_last_balance IS NOT NULL THEN
        SET v_found_last = TRUE;
    ELSE
        SET v_last_balance = 0.00;
    END IF;

    -- 2. Handle Year-End Reset Logic (Month-to-Month is always carried forward)
    IF p_target_month = p_start_month THEN
        -- At the start of the year, we normally reset (based on policy)
        -- But for this sync, we'll let the JS handle the 'Carry Forward' boolean
        -- For now, we assume the opening is what we passed or found
        SET v_opening_leave = v_last_balance;
    ELSE
        -- Within the year, we ALWAYS carry forward
        SET v_opening_leave = v_last_balance;
    END IF;

    -- 3. Calculate Leaves Actually Taken in this month
    SELECT COALESCE(SUM(total_days), 0.00) INTO v_leaves_taken
    FROM leave_requests
    WHERE employee_id = p_emp_id 
    AND leave_type = p_leave_type
    AND status = 'Approved'
    AND DATE_FORMAT(start_date, '%m-%Y') = p_month_year;

    -- 4. Final results
    IF p_is_dry_run = FALSE THEN
        INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
        VALUES (p_emp_id, p_leave_type, p_month_year, v_opening_leave, p_credit_amount, v_leaves_taken)
        ON DUPLICATE KEY UPDATE
            opening_leave = VALUES(opening_leave),
            credited_count = VALUES(credited_count),
            leaves_taken = VALUES(leaves_taken);
    END IF;

    -- Return the values for the report
    SELECT 
        v_opening_leave as openingLeave, 
        p_credit_amount as creditAmount, 
        v_leaves_taken as leavesTaken,
        (v_opening_leave + p_credit_amount) as total,
        (v_opening_leave + p_credit_amount - v_leaves_taken) as balance;

END //

DELIMITER ;
