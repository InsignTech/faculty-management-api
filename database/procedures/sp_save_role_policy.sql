DROP PROCEDURE IF EXISTS `sp_save_role_policy`;

DELIMITER ;;
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
END ;;
DELIMITER ;
