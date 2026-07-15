DROP PROCEDURE IF EXISTS `sp_get_approver_config`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_approver_config`(
    IN p_employee_id INT,
    IN p_request_type ENUM('LEAVE','REGULARISATION','ONDUTY')
)
BEGIN
    -- Returns configured approvers, or falls back to reporting_manager / principal
    DECLARE v_manager_id INT;
    DECLARE v_principal_id INT;

    SELECT reporting_manager_id INTO v_manager_id
    FROM employee WHERE employee_id = p_employee_id;

    SELECT e.employee_id INTO v_principal_id
    FROM employee e
    JOIN app_role r ON e.role_id = r.role_id
    WHERE r.role IN ('Principal','principal') AND e.active = 1
    LIMIT 1;

    SELECT
        COALESCE(eac.approver_1_id, v_manager_id, v_principal_id) AS approver_1_id,
        eac.approver_2_id,
        COALESCE(a1.employee_name, m.employee_name, p.employee_name) AS approver_1_name,
        a2.employee_name AS approver_2_name
    FROM (SELECT 1) dummy
    LEFT JOIN employee_approver_configs eac
        ON eac.employee_id = p_employee_id AND eac.request_type = p_request_type
    LEFT JOIN employee a1 ON a1.employee_id = eac.approver_1_id
    LEFT JOIN employee m  ON m.employee_id  = v_manager_id
    LEFT JOIN employee p  ON p.employee_id  = v_principal_id
    LEFT JOIN employee a2 ON a2.employee_id = eac.approver_2_id;
END ;;
DELIMITER ;
