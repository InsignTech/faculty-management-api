DROP PROCEDURE IF EXISTS `sp_get_departments`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_departments`()
BEGIN
    SELECT 
        department_id,
        departmentname
    FROM department
    ORDER BY department_id DESC;
END ;;
DELIMITER ;
