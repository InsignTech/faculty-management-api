DROP PROCEDURE IF EXISTS `sp_get_designation_by_id`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_designation_by_id`(
    IN p_designation_id INT
)
BEGIN
    SELECT 
        designation_id,
        designation,
        created_on,
        created_by
    FROM designation
    WHERE designation_id = p_designation_id;
END ;;
DELIMITER ;
