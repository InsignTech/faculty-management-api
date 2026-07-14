DROP PROCEDURE IF EXISTS `sp_save_employee_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_save_employee_policy`(
    IN p_leave_policy_id INT,
    IN p_employee_id INT,
    IN p_policy_value LONGTEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    
    UPDATE leave_policy_employee SET active = 0 WHERE employee_id = p_employee_id;
    
    
    IF EXISTS (SELECT 1 FROM leave_policy_employee WHERE employee_id = p_employee_id AND leave_policy_id = p_leave_policy_id) THEN
        UPDATE leave_policy_employee 
        SET policy_value = p_policy_value, active = 1, created_by = p_created_by, created_on = NOW()
        WHERE employee_id = p_employee_id AND leave_policy_id = p_leave_policy_id;
    ELSE
        INSERT INTO leave_policy_employee (leave_policy_id, employee_id, policy_value, active, created_on, created_by)
        VALUES (p_leave_policy_id, p_employee_id, p_policy_value, 1, NOW(), p_created_by);
    END IF;
    
    SELECT 1 AS success;
END ;;
DELIMITER ;
