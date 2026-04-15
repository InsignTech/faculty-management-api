USE `staffdesk`;

DELIMITER //

-- 1. Action Leave Request (Approve/Reject)
DROP PROCEDURE IF EXISTS `sp_action_leave_request` //
CREATE PROCEDURE `sp_action_leave_request`(
    IN p_leave_request_id INT,
    IN p_status ENUM('Pending', 'Approved', 'Rejected'),
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    UPDATE leave_requests
    SET status = p_status,
        approved_by_id = p_approver_id,
        approved_on = NOW(),
        reason = CONCAT(COALESCE(reason, ''), ' | Approver Remarks: ', COALESCE(p_remarks, ''))
    WHERE leave_request_id = p_leave_request_id;

    SELECT ROW_COUNT() AS affected_rows;
END //

-- 2. Get Subordinate Leave Requests (For Managers)
DROP PROCEDURE IF EXISTS `sp_get_subordinate_leave_requests` //
CREATE PROCEDURE `sp_get_subordinate_leave_requests`(
    IN p_manager_id INT,
    IN p_status VARCHAR(50) -- Optional filter: 'Pending', 'Approved', etc.
)
BEGIN
    SELECT 
        lr.*,
        e.employee_name,
        e.employee_code,
        r.role_name as employee_role,
        des.designation_name as employee_designation
    FROM leave_requests lr
    JOIN employee e ON lr.employee_id = e.employee_id
    LEFT JOIN role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    WHERE (e.reporting_manager_id = p_manager_id OR p_manager_id IS NULL) -- Admin might pass NULL for all
      AND (p_status IS NULL OR p_status = '' OR lr.status = p_status)
    ORDER BY lr.applied_on DESC;
END //

-- 3. Get Active Leave Policy Types for an Employee
-- Used to populate the "Leave Type" dropdown in the request form
DROP PROCEDURE IF EXISTS `sp_get_leave_types_by_policy` //
CREATE PROCEDURE `sp_get_leave_types_by_policy`(
    IN p_employee_id INT
)
BEGIN
    DECLARE v_designation_id INT;
    DECLARE v_policy_json LONGTEXT;

    -- 1. Get Employee Designation
    SELECT designation_id INTO v_designation_id FROM employee WHERE employee_id = p_employee_id;

    -- 2. Find the active policy JSON
    SELECT policy_value INTO v_policy_json
    FROM (
        SELECT policy_value, 1 as priority
        FROM leave_policy_employee
        WHERE employee_id = p_employee_id AND active = 1
        UNION ALL
        SELECT lpd.policy_value, 2 as priority
        FROM leave_policy_designation lpd
        JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
        WHERE lpd.designation_id = v_designation_id AND lpd.active = 1 AND lp.policy_year = YEAR(CURDATE())
        UNION ALL
        SELECT policy_value, 3 as priority
        FROM leave_policy_system
        WHERE active = 1 AND policy_year = YEAR(CURDATE())
    ) as policies
    ORDER BY priority ASC
    LIMIT 1;

    -- 3. Parse and return leave types
    IF v_policy_json IS NOT NULL THEN
        SELECT 
            jt.leaveType as leave_type,
            jt.leaveCount as total_allocated
        FROM JSON_TABLE(v_policy_json, '$[*]'
            COLUMNS (
                leaveType VARCHAR(50) PATH '$.leaveType',
                leaveCount INT PATH '$.leaveCount'
            )
        ) AS jt;
    ELSE
        SELECT 'No Policy Found' as leave_type, 0 as total_allocated;
    END IF;
END //

DELIMITER ;
