DROP PROCEDURE IF EXISTS `sp_request_attendance_adjustment`;

DELIMITER ;;
CREATE PROCEDURE `sp_request_attendance_adjustment`(
    IN p_employee_id INT,
    IN p_type ENUM('Regularization', 'OnDuty'),
    IN p_date DATE,
    IN p_punch_time TIME,
    IN p_remarks TEXT,
    IN p_attachment_path VARCHAR(512)
)
BEGIN
    -- Validation for Regularization
    IF p_type = 'Regularization' THEN
        -- Check if regularization is actually needed
        -- Not needed if: Has both In and Out, both are Present, and neither is Late nor Early Leaving
        IF EXISTS (
            SELECT 1 FROM attendance 
            WHERE employee_id = p_employee_id AND date = p_date
            AND status = 'Present' 
            AND is_late = 0 AND is_early_leaving = 0
            GROUP BY employee_id, date
            HAVING COUNT(DISTINCT type) = 2
        ) THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Regularization is not required for this date as attendance is already complete and on-time.';
        END IF;

        -- Optional: Prevent future regularizations if needed
        IF p_date > CURRENT_DATE THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Regularization cannot be requested for future dates.';
        END IF;
    END IF;

    INSERT INTO attendance_adjustments (
        employee_id, type, date, punch_time, remarks, attachment_path, status, requested_on
    ) VALUES (
        p_employee_id, p_type, p_date, p_punch_time, p_remarks, p_attachment_path, 'Pending', NOW()
    );
    
    SELECT LAST_INSERT_ID() AS adjustment_id;
END ;;
DELIMITER ;
