DROP PROCEDURE IF EXISTS `sp_create_leave_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_create_leave_policy`(
    IN p_policy_name VARCHAR(245),
    IN p_policy_year INT,
    IN p_policy_value LONGTEXT,
    IN p_weekly_off TEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    INSERT INTO leave_policy (
        policy_name, policy_year, policy_value, weekly_off, active, created_on, created_by
    )
    VALUES (
        p_policy_name, p_policy_year, p_policy_value, p_weekly_off, 0, NOW(), p_created_by
    );
    
    SELECT LAST_INSERT_ID() AS leave_policy_id;
END ;;
DELIMITER ;
