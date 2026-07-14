DROP PROCEDURE IF EXISTS `sp_update_leave_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_update_leave_policy`(
    IN p_leave_policy_id INT,
    IN p_policy_name VARCHAR(245),
    IN p_policy_year INT,
    IN p_policy_value LONGTEXT,
    IN p_weekly_off TEXT
)
BEGIN
    DECLARE v_active INT;

    UPDATE leave_policy 
    SET policy_name = p_policy_name, 
        policy_year = p_policy_year, 
        policy_value = p_policy_value,
        weekly_off = p_weekly_off
    WHERE leave_policy_id = p_leave_policy_id;

    
    SELECT active INTO v_active 
    FROM leave_policy 
    WHERE leave_policy_id = p_leave_policy_id
    LIMIT 1;

    
    IF v_active = 1 THEN
        INSERT INTO leave_policy_system (
            leave_policy_id, policy_value, weekly_off, policy_year, active, created_by
        )
        VALUES (
            p_leave_policy_id, p_policy_value, p_weekly_off, p_policy_year, 1, 'System Sync'
        )
        ON DUPLICATE KEY UPDATE 
            policy_value = VALUES(policy_value),
            weekly_off = VALUES(weekly_off),
            policy_year = VALUES(policy_year),
            active = 1;
    END IF;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
