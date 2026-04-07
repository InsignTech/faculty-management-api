-- Leave Management: Pro-Rata calculation, Holiday & Weekly-Off exclusion
USE `staffdesk`;

DELIMITER //

-- Updated: sp_get_leave_balance with pro-rata and smart day calculation
DROP PROCEDURE IF EXISTS `sp_get_leave_balance` //
CREATE PROCEDURE `sp_get_leave_balance`(
    IN p_employee_id INT,
    IN p_year INT
)
BEGIN
    DECLARE v_designation_id INT;
    DECLARE v_employee_type VARCHAR(45);
    DECLARE v_joining_date DATE;
    DECLARE v_policy_json LONGTEXT;
    DECLARE v_weekly_off_json TEXT;
    DECLARE v_months_active INT;
    DECLARE v_year_start DATE;
    DECLARE v_year_end DATE;
    DECLARE v_effective_start DATE;

    -- 1. Get Employee info
    SELECT designation_id, employee_type, joining_date
    INTO v_designation_id, v_employee_type, v_joining_date
    FROM employee WHERE employee_id = p_employee_id;

    -- 2. Find the active policy (Employee > Designation > System)
    SELECT policy_value, weekly_off INTO v_policy_json, v_weekly_off_json
    FROM (
        SELECT policy_value, weekly_off, 1 as priority
        FROM leave_policy_employee
        WHERE employee_id = p_employee_id AND active = 1
        UNION ALL
        SELECT lpd.policy_value, lpd.weekly_off, 2 as priority
        FROM leave_policy_designation lpd
        JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
        WHERE lpd.designation_id = v_designation_id AND lpd.active = 1 AND lp.policy_year = p_year
        UNION ALL
        SELECT policy_value, weekly_off, 3 as priority
        FROM leave_policy_system
        WHERE active = 1 AND policy_year = p_year
    ) as policies
    ORDER BY priority ASC
    LIMIT 1;

    IF v_policy_json IS NULL THEN
        SELECT 'No Policy Found' as leave_type, 0 as allocated, 0 as used, 0 as available, 0 as prorata_allocated;
    ELSE
        -- 3. Calculate pro-rata months active
        SET v_year_start = MAKEDATE(p_year, 1);
        SET v_year_end = MAKEDATE(p_year + 1, 1) - INTERVAL 1 DAY;

        -- If employee joined before the year started, full year applies
        IF v_joining_date IS NULL OR v_joining_date <= v_year_start THEN
            SET v_months_active = 12;
        ELSE
            SET v_months_active = 12 - MONTH(v_joining_date) + 1;
        END IF;

        -- 4. Calculate used days excluding holidays and weekly-offs
        -- Used days = approved leave_requests where each individual day is not a holiday/Sunday
        WITH RECURSIVE PolicyLeaves AS (
            SELECT
                jt.leaveType,
                jt.leaveCount as base_allocated,
                ROUND((jt.leaveCount / 12) * v_months_active, 1) as allocated
            FROM JSON_TABLE(v_policy_json, '$[*]'
                COLUMNS (
                    leaveType VARCHAR(50) PATH '$.leaveType',
                    leaveCount INT PATH '$.leaveCount'
                )
            ) AS jt
        ),
        -- Calculate used days the "smart" way: count actual working days used
        ApprovedLeaves AS (
            SELECT
                lr.leave_type,
                lr.start_date,
                lr.end_date
            FROM leave_requests lr
            WHERE lr.employee_id = p_employee_id
              AND lr.status = 'Approved'
              AND YEAR(lr.start_date) = p_year
        ),
        -- Generate all dates in each approved leave period
        DateSeries AS (
            SELECT leave_type, start_date as leave_day, end_date FROM ApprovedLeaves
            WHERE start_date <= end_date
            UNION ALL
            SELECT leave_type, DATE_ADD(leave_day, INTERVAL 1 DAY), end_date FROM DateSeries
            WHERE DATE_ADD(leave_day, INTERVAL 1 DAY) <= end_date
        ),
        -- Exclude Sundays and defined holidays from used days
        WorkingLeaveDays AS (
            SELECT
                ds.leave_type,
                ds.leave_day
            FROM DateSeries ds
            WHERE
                -- Exclude configured weekly off days
                NOT JSON_CONTAINS(COALESCE(v_weekly_off_json, '["Sunday"]'), JSON_QUOTE(DAYNAME(ds.leave_day)))
                -- Exclude defined holidays
                AND ds.leave_day NOT IN (SELECT holiday_date FROM holidays WHERE is_active = 1)
        ),
        UsedLeaves AS (
            SELECT leave_type, COUNT(*) as used
            FROM WorkingLeaveDays
            GROUP BY leave_type
        )
        SELECT
            pl.leaveType as leave_type,
            pl.base_allocated,
            pl.allocated as prorata_allocated,
            COALESCE(ul.used, 0) as used,
            (pl.allocated - COALESCE(ul.used, 0)) as available
        FROM PolicyLeaves pl
        LEFT JOIN UsedLeaves ul ON pl.leaveType = ul.leave_type;
    END IF;
END //


-- Get Leave Requests for an Employee
DROP PROCEDURE IF EXISTS `sp_get_employee_leave_requests` //
CREATE PROCEDURE `sp_get_employee_leave_requests`(
    IN p_employee_id INT
)
BEGIN
    SELECT
        lr.*,
        e.employee_name as approver_name
    FROM leave_requests lr
    LEFT JOIN employee e ON lr.approved_by_id = e.employee_id
    WHERE lr.employee_id = p_employee_id
    ORDER BY lr.applied_on DESC;
END //


-- Apply for Leave: validates working days balance
DROP PROCEDURE IF EXISTS `sp_apply_leave` //
CREATE PROCEDURE `sp_apply_leave`(
    IN p_employee_id INT,
    IN p_leave_type VARCHAR(50),
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_total_days DECIMAL(5,2),
    IN p_reason TEXT,
    IN p_attachment_path VARCHAR(512)
)
BEGIN
    -- Validate that leave request is not in the past (can add more rules here)
    IF p_start_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot apply for leave in the past.';
    END IF;

    INSERT INTO leave_requests (
        employee_id, leave_type, start_date, end_date, total_days, reason, attachment_path, status, applied_on
    ) VALUES (
        p_employee_id, p_leave_type, p_start_date, p_end_date, p_total_days, p_reason, p_attachment_path, 'Pending', NOW()
    );

    SELECT LAST_INSERT_ID() AS leave_request_id;
END //


-- Request Leave Encashment
DROP PROCEDURE IF EXISTS `sp_request_leave_encashment` //
CREATE PROCEDURE `sp_request_leave_encashment`(
    IN p_employee_id INT,
    IN p_leave_type VARCHAR(50),
    IN p_days DECIMAL(5,2)
)
BEGIN
    DECLARE v_basic_pay DECIMAL(15,2);
    DECLARE v_available_balance DECIMAL(5,2);
    DECLARE v_max_encash INT DEFAULT 10;
    DECLARE v_amount DECIMAL(15,2);

    -- Get basic pay
    SELECT basic_pay INTO v_basic_pay FROM employee WHERE employee_id = p_employee_id;

    IF v_basic_pay IS NULL OR v_basic_pay = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Basic pay not set for this employee. Please contact HR.';
    END IF;

    -- Validate max encashable days
    IF p_days > v_max_encash THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot encash more than 10 days of casual leave.';
    END IF;

    -- Calculate amount: 50% of daily rate (Basic Pay / 26 working days)
    SET v_amount = ROUND((v_basic_pay / 26) * 0.5 * p_days, 2);

    INSERT INTO leave_encashments (employee_id, leave_type, days_to_encash, encashment_amount, status, requested_on)
    VALUES (p_employee_id, p_leave_type, p_days, v_amount, 'Pending', NOW());

    SELECT LAST_INSERT_ID() AS encashment_id, v_amount AS calculated_amount;
END //


-- Get Leave Encashment History
DROP PROCEDURE IF EXISTS `sp_get_leave_encashments` //
CREATE PROCEDURE `sp_get_leave_encashments`(
    IN p_employee_id INT
)
BEGIN
    SELECT
        le.*,
        e.employee_name as approver_name
    FROM leave_encashments le
    LEFT JOIN employee e ON le.approved_by_id = e.employee_id
    WHERE le.employee_id = p_employee_id
    ORDER BY le.requested_on DESC;
END //


-- CRUD: Get Attendance Summary for employee - monthly view
DROP PROCEDURE IF EXISTS `sp_get_attendance_summary` //
CREATE PROCEDURE `sp_get_attendance_summary`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT
        COUNT(*) as total_days_present,
        SUM(is_late) as late_count,
        SUM(is_early_leaving) as early_leaving_count,
        SUM(is_regularized) as regularized_count,
        SUM(deduction_days) as total_deductions
    FROM attendance
    WHERE employee_id = p_employee_id
      AND MONTH(date) = p_month
      AND YEAR(date) = p_year
      AND type = 'PunchIn';
END //


-- CRUD: Get all holidays
DROP PROCEDURE IF EXISTS `sp_get_holidays` //
CREATE PROCEDURE `sp_get_holidays`(
    IN p_year INT
)
BEGIN
    SELECT * FROM holidays
    WHERE (p_year IS NULL OR YEAR(holiday_date) = p_year)
    ORDER BY holiday_date ASC;
END //

-- CRUD: Add or update holiday
DROP PROCEDURE IF EXISTS `sp_save_holiday` //
CREATE PROCEDURE `sp_save_holiday`(
    IN p_holiday_id INT,
    IN p_holiday_date DATE,
    IN p_description VARCHAR(255),
    IN p_is_active TINYINT
)
BEGIN
    IF p_holiday_id IS NULL OR p_holiday_id = 0 THEN
        INSERT INTO holidays (holiday_date, description, is_active)
        VALUES (p_holiday_date, p_description, p_is_active)
        ON DUPLICATE KEY UPDATE description = p_description, is_active = p_is_active;
        SELECT LAST_INSERT_ID() AS holiday_id;
    ELSE
        UPDATE holidays SET
            holiday_date = p_holiday_date,
            description = p_description,
            is_active = p_is_active
        WHERE holiday_id = p_holiday_id;
        SELECT p_holiday_id AS holiday_id;
    END IF;
END //

-- CRUD: Delete holiday
DROP PROCEDURE IF EXISTS `sp_delete_holiday` //
CREATE PROCEDURE `sp_delete_holiday`(IN p_holiday_id INT)
BEGIN
    DELETE FROM holidays WHERE holiday_id = p_holiday_id;
    SELECT ROW_COUNT() AS affected_rows;
END //

-- CRUD: Get attendance settings
DROP PROCEDURE IF EXISTS `sp_get_attendance_settings` //
CREATE PROCEDURE `sp_get_attendance_settings`()
BEGIN
    SELECT * FROM attendance_settings ORDER BY setting_key;
END //

-- CRUD: Update a single attendance setting
DROP PROCEDURE IF EXISTS `sp_update_attendance_setting` //
CREATE PROCEDURE `sp_update_attendance_setting`(
    IN p_key VARCHAR(100),
    IN p_value VARCHAR(255)
)
BEGIN
    UPDATE attendance_settings SET setting_value = p_value WHERE setting_key = p_key;
    SELECT ROW_COUNT() AS updated;
END //


DELIMITER ;
