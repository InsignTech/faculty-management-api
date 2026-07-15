DROP PROCEDURE IF EXISTS `sp_update_department`;

DELIMITER ;;
CREATE PROCEDURE `sp_update_department`(
    IN p_department_id INT,
    IN p_departmentname VARCHAR(45)
)
BEGIN
    UPDATE department
    SET departmentname = p_departmentname
    WHERE department_id = p_department_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
