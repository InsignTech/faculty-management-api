DROP PROCEDURE IF EXISTS `sp_update_designation`;

DELIMITER ;;
CREATE PROCEDURE `sp_update_designation`(
    IN p_designation_id INT,
    IN p_designation VARCHAR(45)
)
BEGIN
    UPDATE designation
    SET designation = p_designation
    WHERE designation_id = p_designation_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
