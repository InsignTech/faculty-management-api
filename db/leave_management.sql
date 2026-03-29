-- Leave Management System: Tables and Stored Procedures
USE `staffdesk`;

-- =============================================
-- 1. TABLES
-- =============================================

-- Table for leave requests
CREATE TABLE IF NOT EXISTS `leave_requests` (
    `leave_request_id` INT NOT NULL AUTO_INCREMENT,
    `employee_id` INT NOT NULL,
    `leave_type` VARCHAR(50) NOT NULL,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    `total_days` DECIMAL(5,2) NOT NULL,
    `reason` TEXT,
    `status` ENUM('Pending', 'Approved', 'Rejected', 'Cancelled') DEFAULT 'Pending',
    `applied_on` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `approved_by_id` INT NULL,
    `approved_on` DATETIME NULL,
    `rejection_reason` TEXT NULL,
    `attachment_path` VARCHAR(512) NULL,
    PRIMARY KEY (`leave_request_id`),
    CONSTRAINT `fk_leave_request_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
);

-- =============================================
-- 2. STORED PROCEDURES
-- =============================================

DELIMITER //

-- Get Leave Balance for an Employee
-- Consolidates System, Designation, and Employee level policies
DROP PROCEDURE IF EXISTS `sp_get_leave_balance` //
CREATE PROCEDURE `sp_get_leave_balance`(
    IN p_employee_id INT,
    IN p_year INT
)
BEGIN
    DECLARE v_designation_id INT;
    DECLARE v_policy_json LONGTEXT;
    
    -- 1. Get Employee's Designation
    SELECT designation_id INTO v_designation_id FROM employee WHERE employee_id = p_employee_id;
    
    -- 2. Find High-Priority Policy
    -- Order: Employee-specific > Designation-specific > System-wide active
    SELECT policy_value INTO v_policy_json
    FROM (
        -- Employee Level
        SELECT policy_value, 1 as priority 
        FROM leave_policy_employee 
        WHERE employee_id = p_employee_id AND active = 1
        UNION ALL
        -- Designation Level
        SELECT lpd.policy_value, 2 as priority 
        FROM leave_policy_designation lpd
        JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
        WHERE lpd.designation_id = v_designation_id AND lpd.active = 1 AND lp.policy_year = p_year
        UNION ALL
        -- System Level
        SELECT policy_value, 3 as priority 
        FROM leave_policy 
        WHERE active = 1 AND policy_year = p_year
    ) as policies
    ORDER BY priority ASC
    LIMIT 1;

    -- 3. If no policy found, return empty set (architectural safety)
    IF v_policy_json IS NULL THEN
        SELECT 'No Policy Found' as leave_type, 0 as allocated, 0 as used, 0 as available;
    ELSE
        -- 4. Explode JSON and Calculate Used Leaves
        -- Using a Common Table Expression (CTE) for clarity - Requires MySQL 8.0+
        WITH RECURSIVE PolicyLeaves AS (
            SELECT 
                jt.leaveType,
                jt.leaveCount as allocated
            FROM JSON_TABLE(v_policy_json, '$[*]' 
                COLUMNS (
                    leaveType VARCHAR(50) PATH '$.leaveType',
                    leaveCount INT PATH '$.leaveCount'
                )
            ) AS jt
        ),
        UsedLeaves AS (
            SELECT 
                leave_type,
                SUM(total_days) as used
            FROM leave_requests
            WHERE employee_id = p_employee_id 
              AND status = 'Approved'
              AND YEAR(start_date) = p_year
            GROUP BY leave_type
        )
        SELECT 
            pl.leaveType as leave_type,
            pl.allocated,
            COALESCE(ul.used, 0) as used,
            (pl.allocated - COALESCE(ul.used, 0)) as available
        FROM PolicyLeaves pl
        LEFT JOIN UsedLeaves ul ON pl.leaveType = ul.leave_type;
    END IF;
END //

-- Apply for Leave
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
    -- Architecture: We could add balance validation here too
    INSERT INTO leave_requests (
        employee_id, leave_type, start_date, end_date, total_days, reason, attachment_path, status, applied_on
    ) VALUES (
        p_employee_id, p_leave_type, p_start_date, p_end_date, p_total_days, p_reason, p_attachment_path, 'Pending', NOW()
    );
    
    SELECT LAST_INSERT_ID() AS leave_request_id;
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

DELIMITER ;
