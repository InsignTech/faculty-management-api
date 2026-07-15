DROP PROCEDURE IF EXISTS `sp_get_designations`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_designations`()
BEGIN
    SELECT 
        designation_id,
        designation,
        created_on,
        created_by
    FROM designation
    ORDER BY designation_id DESC;
END ;;
DELIMITER ;
