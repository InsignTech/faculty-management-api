DROP PROCEDURE IF EXISTS `sp_get_leave_balance`;

DELIMITER ;;
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

    
    SELECT designation_id, role_id, joining_date
    INTO v_designation_id, v_role_id, v_joining_date
    FROM employee WHERE employee_id = p_employee_id;

    
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
        
        SELECT lpr.policy_value, lpr.weekly_off, 3 as priority
        FROM leave_policy_role lpr
        JOIN leave_policy lp ON lpr.leave_policy_id = lp.leave_policy_id
        WHERE lpr.role_id = v_role_id AND lpr.active = 1 AND lp.policy_year = p_year
        UNION ALL
        
        SELECT policy_value, weekly_off, 4 as priority
        FROM leave_policy_system
        WHERE active = 1 AND policy_year = p_year
    ) as policies
    ORDER BY priority ASC
    LIMIT 1;

    IF v_policy_json IS NULL THEN
        SELECT 'No Policy Found' as leave_type, 0 as allocated, 0 as used, 0 as available, 0 as prorata_allocated;
    ELSE
        
        SET v_year_start = MAKEDATE(p_year, 1);
        SET v_year_end = MAKEDATE(p_year + 1, 1) - INTERVAL 1 DAY;

        IF v_joining_date IS NULL OR v_joining_date <= v_year_start THEN
            SET v_months_active = 12;
        ELSE
            SET v_months_active = 12 - MONTH(v_joining_date) + 1;
        END IF;

        
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
END ;;
DELIMITER ;
