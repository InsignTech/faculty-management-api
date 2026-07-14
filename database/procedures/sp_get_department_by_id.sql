DROP PROCEDURE IF EXISTS `sp_get_department_by_id`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_department_by_id`(
    IN p_department_id INT
)
BEGIN
    SELECT 
        department_id,
        departmentname
    FROM department
    WHERE department_id = p_department_id;
END ;;
DELIMITER ;
