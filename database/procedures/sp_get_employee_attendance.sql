DROP PROCEDURE IF EXISTS `sp_get_employee_attendance`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_employee_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT
        MIN(a.attendance_id) AS attendance_id,
        a.employee_id,
        a.date,
        MIN(a.first_in_time) AS first_in_time,
        MAX(a.last_out_time) AS last_out_time,
        SUM(a.worked_mins) AS worked_mins,
        IF(COUNT(DISTINCT a.shift_type) > 1, 'Split', MAX(a.shift_type)) AS shift_type,
        GROUP_CONCAT(a.status ORDER BY a.shift_type SEPARATOR ' / ') AS status,
        MAX(a.is_late) AS is_late,
        SUM(a.late_minutes) AS late_minutes,
        MAX(a.is_early_leaving) AS is_early_leaving,
        SUM(a.early_minutes) AS early_minutes,
        SUM(a.overtime_minutes) AS overtime_minutes,
        SUM(a.deduction_days) AS deduction_days,
        MAX(a.is_worked_on_holiday) AS is_worked_on_holiday,
        MAX(IF(a.status = 'Regularized', a.shift_type, NULL)) AS regularization_shift_type,
        MAX(IF(a.status = 'OnDuty', a.shift_type, NULL)) AS onduty_shift_type,
        MAX(IF(a.status = 'Leave', 1, 0)) AS is_leave,
        MAX(IF(a.status = 'Leave', a.shift_type, NULL)) AS leave_shift_type,
        MAX(IF(a.shift_type = 'FirstHalf', a.status, NULL)) AS first_half_status,
        MAX(IF(a.shift_type = 'SecondHalf', a.status, NULL)) AS second_half_status,
        MIN(a.created_on) AS created_on,
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
            WHERE lr.employee_id = a.employee_id
              AND lr.status = 'Approved'
              AND a.date BETWEEN lr.start_date AND lr.end_date
        ) AS leave_details
    FROM attendance a
    WHERE a.employee_id = p_employee_id
      AND MONTH(a.date) = p_month
      AND YEAR(a.date) = p_year
    GROUP BY a.employee_id, a.date
    ORDER BY a.date DESC;
END ;;
DELIMITER ;
