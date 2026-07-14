DROP PROCEDURE IF EXISTS `sp_delete_designation`;

DELIMITER ;;
CREATE PROCEDURE `sp_delete_designation`(
    IN p_designation_id INT
)
BEGIN
    DELETE FROM designation
    WHERE designation_id = p_designation_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
