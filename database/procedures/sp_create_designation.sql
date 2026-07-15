DROP PROCEDURE IF EXISTS `sp_create_designation`;

DELIMITER ;;
CREATE PROCEDURE `sp_create_designation`(
    IN p_designation VARCHAR(45),
    IN p_created_by VARCHAR(45)
)
BEGIN
    INSERT INTO designation (designation, created_on, created_by)
    VALUES (p_designation, NOW(), p_created_by);

    SELECT LAST_INSERT_ID() AS designation_id;
END ;;
DELIMITER ;
