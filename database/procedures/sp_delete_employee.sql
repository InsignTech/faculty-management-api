DROP PROCEDURE IF EXISTS `sp_delete_employee`;

DELIMITER ;;
CREATE PROCEDURE `sp_delete_employee`(
    IN p_employee_id INT
)
BEGIN
    DECLARE v_rows INT DEFAULT 0;

    
    UPDATE employee
    SET 
        active = 0,
        modified_on = NOW()
    WHERE employee_id = p_employee_id;

    SET v_rows = ROW_COUNT();

    
    UPDATE user_accounts
    SET 
        active = 0,
        created_on = created_on 
    WHERE employee_id = p_employee_id;

    SELECT v_rows AS affected_rows;

END ;;
DELIMITER ;
