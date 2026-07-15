DROP PROCEDURE IF EXISTS `sp_get_employee_attendance`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_employee_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN

    SELECT
        ad.*,

        (
            SELECT GROUP_CONCAT(
                CONCAT(
                    lr.leave_type,
                    ' (',
                    lr.leave_half_type,
                    ')'
                )
                SEPARATOR ', '
            )
            FROM leave_requests lr
            WHERE lr.employee_id = ad.employee_id
              AND lr.status = 'Approved'
              AND ad.date BETWEEN lr.start_date AND lr.end_date
        ) AS leave_details

    FROM attendance_daily ad

    WHERE ad.employee_id = p_employee_id
      AND MONTH(ad.date) = p_month
      AND YEAR(ad.date) = p_year

    ORDER BY ad.date DESC;

END ;;
DELIMITER ;
