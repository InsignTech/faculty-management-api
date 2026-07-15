DROP PROCEDURE IF EXISTS `sp_action_leave_request`;

DELIMITER ;;
CREATE PROCEDURE `sp_action_leave_request`(
    IN p_leave_request_id INT,
    IN p_status ENUM('Pending', 'Approved', 'Rejected'),
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    UPDATE leave_requests
    SET status = p_status,
        approved_by_id = p_approver_id,
        approved_on = NOW(),
        reason = CONCAT(COALESCE(reason, ''), ' | Approver Remarks: ', COALESCE(p_remarks, ''))
    WHERE leave_request_id = p_leave_request_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
