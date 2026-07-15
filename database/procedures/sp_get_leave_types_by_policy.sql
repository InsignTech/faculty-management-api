DROP PROCEDURE IF EXISTS `sp_get_leave_types_by_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_leave_types_by_policy`(
    IN p_employee_id INT
)
BEGIN
    DECLARE v_designation_id INT;
    DECLARE v_policy_json LONGTEXT;

    
    SELECT designation_id INTO v_designation_id FROM employee WHERE employee_id = p_employee_id;

    
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
END ;;
DELIMITER ;
