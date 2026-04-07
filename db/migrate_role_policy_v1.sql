-- Migration: Role-Based Leave Policies
-- Implementing Role-level policy overrides and updating the priority chain
USE `staffdesk`;

-- 1. Create leave_policy_role table
CREATE TABLE IF NOT EXISTS `leave_policy_role` (
    `leave_policy_role_id` INT AUTO_INCREMENT PRIMARY KEY,
    `leave_policy_id` INT NOT NULL,
    `role_id` INT NOT NULL,
    `policy_value` LONGTEXT NOT NULL, -- JSON array of leave types
    `weekly_off` TEXT,                -- JSON array of days ["Sunday"]
    `active` TINYINT DEFAULT 1,
    `created_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `created_by` VARCHAR(100),
    FOREIGN KEY (`leave_policy_id`) REFERENCES `leave_policy` (`leave_policy_id`),
    UNIQUE KEY `idx_role_policy` (`role_id`, `leave_policy_id`)
);

DELIMITER //

-- 2. Update sp_get_leave_balance to include Role layer
DROP PROCEDURE IF EXISTS `sp_get_leave_balance` //
CREATE PROCEDURE `sp_get_leave_balance`(
    IN p_employee_id INT,
    IN p_year INT
)
BEGIN
    DECLARE v_designation_id INT;
    DECLARE v_role_id INT;
    DECLARE v_joining_date DATE;
    DECLARE v_policy_json LONGTEXT;
    DECLARE v_weekly_off_json TEXT;
    DECLARE v_months_active INT;
    DECLARE v_year_start DATE;
    DECLARE v_year_end DATE;

    -- 1. Get Employee info
    SELECT designation_id, role_id, joining_date
    INTO v_designation_id, v_role_id, v_joining_date
    FROM employee WHERE employee_id = p_employee_id;

    -- 2. Find the active policy (Employee > Designation > Role > System)
    SELECT policy_value, weekly_off INTO v_policy_json, v_weekly_off_json
    FROM (
        -- Level 1: Employee Specific
        SELECT policy_value, weekly_off, 1 as priority
        FROM leave_policy_employee
        WHERE employee_id = p_employee_id AND active = 1
        UNION ALL
        -- Level 2: Designation Specific
        SELECT lpd.policy_value, lpd.weekly_off, 2 as priority
        FROM leave_policy_designation lpd
        JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
        WHERE lpd.designation_id = v_designation_id AND lpd.active = 1 AND lp.policy_year = p_year
        UNION ALL
        -- Level 3: Role Specific (New)
        SELECT lpr.policy_value, lpr.weekly_off, 3 as priority
        FROM leave_policy_role lpr
        JOIN leave_policy lp ON lpr.leave_policy_id = lp.leave_policy_id
        WHERE lpr.role_id = v_role_id AND lpr.active = 1 AND lp.policy_year = p_year
        UNION ALL
        -- Level 4: System Level Baseline
        SELECT policy_value, weekly_off, 4 as priority
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

        IF v_joining_date IS NULL OR v_joining_date <= v_year_start THEN
            SET v_months_active = 12;
        ELSE
            SET v_months_active = 12 - MONTH(v_joining_date) + 1;
        END IF;

        -- 4. Calculate used days excluding holidays and weekly-offs
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
        DateSeries AS (
            SELECT leave_type, start_date as leave_day, end_date FROM ApprovedLeaves
            WHERE start_date <= end_date
            UNION ALL
            SELECT leave_type, DATE_ADD(leave_day, INTERVAL 1 DAY), end_date FROM DateSeries
            WHERE DATE_ADD(leave_day, INTERVAL 1 DAY) <= end_date
        ),
        WorkingLeaveDays AS (
            SELECT
                ds.leave_type,
                ds.leave_day
            FROM DateSeries ds
            WHERE
                NOT JSON_CONTAINS(COALESCE(v_weekly_off_json, '["Sunday"]'), JSON_QUOTE(DAYNAME(ds.leave_day)))
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

-- 3. CRUD: Get Role Policy
DROP PROCEDURE IF EXISTS `sp_get_role_policy` //
CREATE PROCEDURE `sp_get_role_policy`(
    IN p_role_id INT
)
BEGIN
    SELECT 
        lpr.*,
        lp.policy_name,
        lp.policy_year
    FROM leave_policy_role lpr
    JOIN leave_policy lp ON lpr.leave_policy_id = lp.leave_policy_id
    WHERE lpr.role_id = p_role_id AND lpr.active = 1;
END //

-- 4. CRUD: Save Role Policy
DROP PROCEDURE IF EXISTS `sp_save_role_policy` //
CREATE PROCEDURE `sp_save_role_policy`(
    IN p_leave_policy_id INT,
    IN p_role_id INT,
    IN p_policy_value LONGTEXT,
    IN p_weekly_off TEXT,
    IN p_created_by VARCHAR(100)
)
BEGIN
    INSERT INTO leave_policy_role (
        leave_policy_id, role_id, policy_value, weekly_off, created_by
    ) VALUES (
        p_leave_policy_id, p_role_id, p_policy_value, p_weekly_off, p_created_by
    )
    ON DUPLICATE KEY UPDATE 
        policy_value = VALUES(policy_value),
        weekly_off = VALUES(weekly_off),
        active = 1;
        
    SELECT LAST_INSERT_ID() AS leave_policy_role_id;
END //

DELIMITER ;
