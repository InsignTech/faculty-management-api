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
        CALL sp_process_attendance(v_date);
        SET v_date = DATE_ADD(v_date, INTERVAL 1 DAY);
    END WHILE;

END ;;
DELIMITER ;
