DROP PROCEDURE IF EXISTS `sp_apply_leave`;

DELIMITER ;;
CREATE PROCEDURE `sp_apply_leave`(
    IN p_employee_id          INT,
    IN p_leave_type           VARCHAR(50),
    IN p_start_date           DATE,
    IN p_end_date             DATE,
    IN p_total_days           DECIMAL(5,2),
    IN p_reason               TEXT,
    IN p_attachment_path      VARCHAR(512),
    IN p_substitute_id        INT,
    IN p_approver_1_id        INT,
    IN p_approver_2_id        INT,
    IN p_leave_half_type      VARCHAR(20)
)
BEGIN
    DECLARE v_principal_id INT;
    DECLARE v_manager_id   INT;
    DECLARE v_a1           INT;
    DECLARE v_a2           INT;

    /* Allow only current month and future dates */
    IF p_start_date < DATE_FORMAT(CURDATE(), '%Y-%m-01') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Leave can only be applied within the current month.';
    END IF;

    SELECT reporting_manager_id
    INTO v_manager_id
    FROM employee
    WHERE employee_id = p_employee_id;

    /* Adjust this query if your table is roles instead of app_role */
    SELECT e.employee_id
    INTO v_principal_id
    FROM employee e
    JOIN app_role r ON e.role_id = r.role_id
    WHERE r.role IN ('Principal','principal')
      AND e.active = 1
    LIMIT 1;

    SET v_a1 = COALESCE(p_approver_1_id, v_manager_id, v_principal_id);
    SET v_a2 = p_approver_2_id;

    IF p_approver_1_id IS NULL THEN

        SELECT
            COALESCE(
                eac.approver_1_id,
                v_manager_id,
                v_principal_id
            ),
            eac.approver_2_id
        INTO v_a1, v_a2
        FROM (SELECT 1) d
        LEFT JOIN employee_approver_configs eac
            ON eac.employee_id = p_employee_id
           AND eac.request_type = 'LEAVE';

        SET v_a1 = COALESCE(
            v_a1,
            v_manager_id,
            v_principal_id
        );

    END IF;

    INSERT INTO leave_requests (
        employee_id,
        leave_type,
        start_date,
        end_date,
        total_days,
        leave_half_type,
        reason,
        attachment_path,
        status,
        applied_on,
        substitute_employee_id,
        approver_1_id,
        approver_2_id,
        current_level
    )
    VALUES (
        p_employee_id,
        p_leave_type,
        p_start_date,
        p_end_date,
        p_total_days,
        COALESCE(p_leave_half_type, 'FullDay'),
        p_reason,
        p_attachment_path,
        'Pending',
        NOW(),
        p_substitute_id,
        v_a1,
        v_a2,
        1
    );

    SELECT LAST_INSERT_ID() AS leave_request_id;

END ;;
DELIMITER ;
