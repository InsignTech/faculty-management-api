DROP PROCEDURE IF EXISTS `sp_create_department`;

DELIMITER ;;
CREATE PROCEDURE `sp_create_department`(
    IN p_departmentname VARCHAR(45)
)
BEGIN
    INSERT INTO department (departmentname)
    VALUES (p_departmentname);

    SELECT LAST_INSERT_ID() AS department_id;
END ;;
DELIMITER ;
