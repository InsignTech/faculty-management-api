-- Stored Procedures for Designation Management
USE staffdesk;

DELIMITER $$

-- Create Designation
CREATE PROCEDURE IF NOT EXISTS sp_create_designation(
    IN p_designation VARCHAR(45),
    IN p_created_by VARCHAR(45)
)
BEGIN
    INSERT INTO designation (designation, created_on, created_by)
    VALUES (p_designation, NOW(), p_created_by);

    SELECT LAST_INSERT_ID() AS designation_id;
END $$

-- Get All Designations
CREATE PROCEDURE IF NOT EXISTS sp_get_designations()
BEGIN
    SELECT 
        designation_id,
        designation,
        created_on,
        created_by
    FROM designation
    ORDER BY designation_id DESC;
END $$

-- Get Designation By ID
CREATE PROCEDURE IF NOT EXISTS sp_get_designation_by_id(
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
END $$

-- Update Designation
CREATE PROCEDURE IF NOT EXISTS sp_update_designation(
    IN p_designation_id INT,
    IN p_designation VARCHAR(45)
)
BEGIN
    UPDATE designation
    SET designation = p_designation
    WHERE designation_id = p_designation_id;

    SELECT ROW_COUNT() AS affected_rows;
END $$

-- Delete Designation
CREATE PROCEDURE IF NOT EXISTS sp_delete_designation(
    IN p_designation_id INT
)
BEGIN
    DELETE FROM designation
    WHERE designation_id = p_designation_id;

    SELECT ROW_COUNT() AS affected_rows;
END $$

DELIMITER ;
