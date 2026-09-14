DROP PROCEDURE IF EXISTS `sp_process_attendance_range`;

DELIMITER ;;
CREATE PROCEDURE `sp_process_attendance_range`(
    IN p_start DATE,
    IN p_end   DATE
)
BEGIN
    DECLARE v_date DATE;
    SET v_date = p_start;

    WHILE v_date <= p_end DO
        IF v_date < CURDATE() OR (v_date = CURDATE() AND CURRENT_TIME() >= '19:00:00') THEN
            CALL sp_process_attendance_shiftwise(v_date, NULL);
        END IF;
        SET v_date = DATE_ADD(v_date, INTERVAL 1 DAY);
    END WHILE;

END ;;
DELIMITER ;
