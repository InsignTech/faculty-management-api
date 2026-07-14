DROP PROCEDURE IF EXISTS `sp_check_substitute_availability`;

DELIMITER ;;
CREATE PROCEDURE `sp_check_substitute_availability`(
    IN p_substitute_id INT,
    IN p_start_date    DATE,
    IN p_end_date      DATE
)
BEGIN
    -- Returns rows if substitute has conflicting approved/pending leave
    SELECT
        lr.leave_request_id,
        lr.start_date,
        lr.end_date,
        lr.leave_type,
        lr.status
    FROM leave_requests lr
    WHERE lr.employee_id = p_substitute_id
      AND lr.status IN ('Pending','Approved')
      AND lr.start_date <= p_end_date
      AND lr.end_date   >= p_start_date
    LIMIT 5;
END ;;
DELIMITER ;
