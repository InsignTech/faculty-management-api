-- Stored Procedures for Multi-level Leave Policy Management
USE `staffdesk`;

DELIMITER //

-- =============================================
-- SYSTEM LEVEL POLICIES
-- =============================================

-- Get all system policies
DROP PROCEDURE IF EXISTS `sp_get_leave_policies` //
CREATE PROCEDURE `sp_get_leave_policies`()
BEGIN
    SELECT * FROM leave_policy ORDER BY policy_year DESC, created_on DESC;
END //

-- Create system policy
DROP PROCEDURE IF EXISTS `sp_create_leave_policy` //
CREATE PROCEDURE `sp_create_leave_policy`(
    IN p_policy_name VARCHAR(245),
    IN p_policy_year INT,
    IN p_policy_value LONGTEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    INSERT INTO leave_policy (policy_name, policy_year, policy_value, active, created_on, created_by)
    VALUES (p_policy_name, p_policy_year, p_policy_value, 0, NOW(), p_created_by);
    
    SELECT LAST_INSERT_ID() AS leave_policy_id;
END //

-- Update system policy
DROP PROCEDURE IF EXISTS `sp_update_leave_policy` //
CREATE PROCEDURE `sp_update_leave_policy`(
    IN p_leave_policy_id INT,
    IN p_policy_name VARCHAR(245),
    IN p_policy_year INT,
    IN p_policy_value LONGTEXT
)
BEGIN
    UPDATE leave_policy 
    SET policy_name = p_policy_name, 
        policy_year = p_policy_year, 
        policy_value = p_policy_value
    WHERE leave_policy_id = p_leave_policy_id;
    
    SELECT ROW_COUNT() AS affected_rows;
END //

-- Set active system policy (only one can be active at a time)
DROP PROCEDURE IF EXISTS `sp_set_active_leave_policy` //
CREATE PROCEDURE `sp_set_active_leave_policy`(
    IN p_leave_policy_id INT
)
BEGIN
    -- Deactivate all
    UPDATE leave_policy SET active = 0;
    -- Activate the selected one
    UPDATE leave_policy SET active = 1 WHERE leave_policy_id = p_leave_policy_id;
    
    SELECT ROW_COUNT() AS affected_rows;
END //

-- Delete system policy (cannot delete active policy)
DROP PROCEDURE IF EXISTS `sp_delete_leave_policy` //
CREATE PROCEDURE `sp_delete_leave_policy`(
    IN p_leave_policy_id INT
)
BEGIN
    DECLARE v_active TINYINT;
    
    SELECT active INTO v_active FROM leave_policy WHERE leave_policy_id = p_leave_policy_id;
    
    IF v_active = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete an active system policy';
    ELSE
        DELETE FROM leave_policy WHERE leave_policy_id = p_leave_policy_id;
        SELECT ROW_COUNT() AS affected_rows;
    END IF;
END //


-- =============================================
-- DESIGNATION LEVEL POLICIES
-- =============================================

-- Get policy for a specific designation
DROP PROCEDURE IF EXISTS `sp_get_designation_policy` //
CREATE PROCEDURE `sp_get_designation_policy`(
    IN p_designation_id INT
)
BEGIN
    SELECT lpd.*, lp.policy_name, lp.policy_year
    FROM leave_policy_designation lpd
    JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
    WHERE lpd.designation_id = p_designation_id AND lpd.active = 1;
END //

-- Save designation policy (Create or Update)
DROP PROCEDURE IF EXISTS `sp_save_designation_policy` //
CREATE PROCEDURE `sp_save_designation_policy`(
    IN p_leave_policy_id INT,
    IN p_designation_id INT,
    IN p_policy_value LONGTEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    -- Deactivate any previous active policy for this designation
    UPDATE leave_policy_designation SET active = 0 WHERE designation_id = p_designation_id;
    
    -- Check if it already exists to update or insert new
    IF EXISTS (SELECT 1 FROM leave_policy_designation WHERE designation_id = p_designation_id AND leave_policy_id = p_leave_policy_id) THEN
        UPDATE leave_policy_designation 
        SET policy_value = p_policy_value, active = 1, created_by = p_created_by, created_on = NOW()
        WHERE designation_id = p_designation_id AND leave_policy_id = p_leave_policy_id;
    ELSE
        INSERT INTO leave_policy_designation (leave_policy_id, designation_id, policy_value, active, created_on, created_by)
        VALUES (p_leave_policy_id, p_designation_id, p_policy_value, 1, NOW(), p_created_by);
    END IF;
    
    SELECT 1 AS success;
END //


-- =============================================
-- EMPLOYEE LEVEL POLICIES
-- =============================================

-- Get policy for a specific employee
DROP PROCEDURE IF EXISTS `sp_get_employee_policy` //
CREATE PROCEDURE `sp_get_employee_policy`(
    IN p_employee_id INT
)
BEGIN
    SELECT lpe.*, lp.policy_name, lp.policy_year
    FROM leave_policy_employee lpe
    JOIN leave_policy lp ON lpe.leave_policy_id = lp.leave_policy_id
    WHERE lpe.employee_id = p_employee_id AND lpe.active = 1;
END //

-- Save employee policy (Create or Update)
DROP PROCEDURE IF EXISTS `sp_save_employee_policy` //
CREATE PROCEDURE `sp_save_employee_policy`(
    IN p_leave_policy_id INT,
    IN p_employee_id INT,
    IN p_policy_value LONGTEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    -- Deactivate any previous active policy for this employee
    UPDATE leave_policy_employee SET active = 0 WHERE employee_id = p_employee_id;
    
    -- Check if it already exists
    IF EXISTS (SELECT 1 FROM leave_policy_employee WHERE employee_id = p_employee_id AND leave_policy_id = p_leave_policy_id) THEN
        UPDATE leave_policy_employee 
        SET policy_value = p_policy_value, active = 1, created_by = p_created_by, created_on = NOW()
        WHERE employee_id = p_employee_id AND leave_policy_id = p_leave_policy_id;
    ELSE
        INSERT INTO leave_policy_employee (leave_policy_id, employee_id, policy_value, active, created_on, created_by)
        VALUES (p_leave_policy_id, p_employee_id, p_policy_value, 1, NOW(), p_created_by);
    END IF;
    
    SELECT 1 AS success;
END //

DELIMITER ;
