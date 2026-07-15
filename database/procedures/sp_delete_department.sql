DROP PROCEDURE IF EXISTS `sp_delete_department`;

DELIMITER ;;
CREATE PROCEDURE `sp_delete_department`(
    IN p_department_id INT
)
BEGIN
    DELETE FROM department
    WHERE department_id = p_department_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
