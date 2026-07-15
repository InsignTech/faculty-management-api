DROP PROCEDURE IF EXISTS `sp_get_employee_adjustments`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_employee_adjustments`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        aj.*,
        e.employee_name as approver_name
    FROM attendance_adjustments aj
    LEFT JOIN employee e ON aj.approved_by_id = e.employee_id
    WHERE aj.employee_id = p_employee_id
      AND (p_month IS NULL OR MONTH(aj.date) = p_month)
      AND (p_year IS NULL OR YEAR(aj.date) = p_year)
    ORDER BY aj.requested_on DESC;
END ;;
DELIMITER ;
