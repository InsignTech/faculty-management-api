DROP PROCEDURE IF EXISTS `sp_save_designation_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_save_designation_policy`(
    IN p_leave_policy_id INT,
    IN p_designation_id INT,
    IN p_policy_value LONGTEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    
    UPDATE leave_policy_designation SET active = 0 WHERE designation_id = p_designation_id;
    
    
    IF EXISTS (SELECT 1 FROM leave_policy_designation WHERE designation_id = p_designation_id AND leave_policy_id = p_leave_policy_id) THEN
        UPDATE leave_policy_designation 
        SET policy_value = p_policy_value, active = 1, created_by = p_created_by, created_on = NOW()
        WHERE designation_id = p_designation_id AND leave_policy_id = p_leave_policy_id;
    ELSE
        INSERT INTO leave_policy_designation (leave_policy_id, designation_id, policy_value, active, created_on, created_by)
        VALUES (p_leave_policy_id, p_designation_id, p_policy_value, 1, NOW(), p_created_by);
    END IF;
    
    SELECT 1 AS success;
END ;;
DELIMITER ;
