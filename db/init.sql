-- Create Database
CREATE DATABASE IF NOT EXISTS university_db;
USE university_db;

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('Admin', 'HOD', 'Faculty') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stored Procedure: Signup
DELIMITER //
CREATE PROCEDURE sp_signup(
    IN p_username VARCHAR(255),
    IN p_email VARCHAR(255),
    IN p_password VARCHAR(255),
    IN p_role VARCHAR(50)
)
BEGIN
    INSERT INTO users (username, email, password, role)
    VALUES (p_username, p_email, p_password, p_role);
    
    SELECT id, username, email, role, created_at FROM users WHERE id = LAST_INSERT_ID();
END //
DELIMITER ;

-- Stored Procedure: Login
DELIMITER //
CREATE PROCEDURE sp_login(
    IN p_email VARCHAR(255)
)
BEGIN
    SELECT id, username, email, password, role FROM users WHERE email = p_email;
END //
DELIMITER ;

-- Stored Procedure: Get Faculty Profile
DELIMITER //
CREATE PROCEDURE sp_get_faculty_profile(
    IN p_user_id INT
)
BEGIN
    SELECT id, username, email, role, created_at FROM users WHERE id = p_user_id;
END //
DELIMITER ;
