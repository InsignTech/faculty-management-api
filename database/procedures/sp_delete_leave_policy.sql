DROP PROCEDURE IF EXISTS `sp_delete_leave_policy`;

DELIMITER ;;
CREATE PROCEDURE `sp_delete_leave_policy`(
    IN p_leave_policy_id INT
)
BEGIN
    DECLARE v_active TINYINT;
    
    SELECT active INTO v_active FROM leave_policy WHERE leave_policy_id = p_leave_policy_id;
    
    IF v_active = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete an active system policy';
    ELSE
        DELETE FROM leave_policy WHERE leave_policy_id = p_leave_policy_id;
        SELECT ROW_COUNT() AS affected_rows;
    END IF;
END ;;
DELIMITER ;
