DROP PROCEDURE IF EXISTS `sp_set_active_leave_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_set_active_leave_policy`(
    IN p_leave_policy_id INT
)
BEGIN
    DECLARE v_policy_year INT;
    DECLARE v_policy_value LONGTEXT;
    DECLARE v_weekly_off TEXT;
    DECLARE v_created_by VARCHAR(45);

    
    SELECT policy_year, policy_value, weekly_off, created_by
    INTO v_policy_year, v_policy_value, v_weekly_off, v_created_by
    FROM leave_policy 
    WHERE leave_policy_id = p_leave_policy_id
    LIMIT 1;

    
    UPDATE leave_policy 
    SET active = 0 
    WHERE policy_year = v_policy_year;

    
    UPDATE leave_policy 
    SET active = 1 
    WHERE leave_policy_id = p_leave_policy_id;
    
    
    UPDATE leave_policy_system 
    SET active = 0 
    WHERE policy_year = v_policy_year;

    INSERT INTO leave_policy_system (
        leave_policy_id, policy_value, weekly_off, policy_year, active, created_by
    )
    VALUES (
        p_leave_policy_id, v_policy_value, v_weekly_off, v_policy_year, 1, v_created_by
    )
    ON DUPLICATE KEY UPDATE 
        leave_policy_id = VALUES(leave_policy_id),
        policy_value = VALUES(policy_value),
        weekly_off = VALUES(weekly_off),
        active = 1;
    
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
