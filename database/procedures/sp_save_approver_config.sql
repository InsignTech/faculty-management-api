DROP PROCEDURE IF EXISTS `sp_save_approver_config`;

DELIMITER ;;
CREATE PROCEDURE `sp_save_approver_config`(
    IN p_employee_id   INT,
    IN p_request_type  ENUM('LEAVE','REGULARISATION','ONDUTY'),
    IN p_approver_1_id INT,
    IN p_approver_2_id INT
)
BEGIN
    INSERT INTO employee_approver_configs (employee_id, request_type, approver_1_id, approver_2_id)
    VALUES (p_employee_id, p_request_type, p_approver_1_id, p_approver_2_id)
    ON DUPLICATE KEY UPDATE
        approver_1_id = p_approver_1_id,
        approver_2_id = p_approver_2_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
