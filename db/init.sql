-- Create Database
CREATE DATABASE IF NOT EXISTS staffdesk;
USE staffdesk;

-- User Accounts Table
CREATE TABLE IF NOT EXISTS user_accounts (
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
    INSERT INTO user_accounts (username, email, password, role)
    VALUES (p_username, p_email, p_password, p_role);
    
    SELECT id, username, email, role, created_at FROM user_accounts WHERE id = LAST_INSERT_ID();
END //
DELIMITER ;

-- Stored Procedure: Login
DELIMITER //
CREATE PROCEDURE sp_login(
    IN p_email VARCHAR(255)
)
BEGIN
    SELECT id, username, email, password, role FROM user_accounts WHERE email = p_email;
END //
DELIMITER ;

-- Stored Procedure: Get Faculty Profile
DELIMITER //
CREATE PROCEDURE sp_get_faculty_profile(
    IN p_user_id INT
)
BEGIN
    SELECT id, username, email, role, created_at FROM user_accounts WHERE id = p_user_id;
END //
DELIMITER ;

-- Department Table
CREATE TABLE IF NOT EXISTS department (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    departmentname VARCHAR(45) NOT NULL UNIQUE
);

-- Stored Procedure: Create Department
DELIMITER $$
CREATE PROCEDURE sp_create_department(
    IN p_departmentname VARCHAR(45)
)
BEGIN
    INSERT INTO department (departmentname)
    VALUES (p_departmentname);

    SELECT LAST_INSERT_ID() AS department_id;
END $$
DELIMITER ;

-- Stored Procedure: Get All Departments
DELIMITER $$
CREATE PROCEDURE sp_get_departments()
BEGIN
    SELECT 
        department_id,
        departmentname
    FROM department
    ORDER BY department_id DESC;
END $$
DELIMITER ;

-- Stored Procedure: Get Department By ID
DELIMITER $$
CREATE PROCEDURE sp_get_department_by_id(
    IN p_department_id INT
)
BEGIN
    SELECT 
        department_id,
        departmentname
    FROM department
    WHERE department_id = p_department_id;
END $$
DELIMITER ;

-- Stored Procedure: Update Department
DELIMITER $$
CREATE PROCEDURE sp_update_department(
    IN p_department_id INT,
    IN p_departmentname VARCHAR(45)
)
BEGIN
    UPDATE department
    SET departmentname = p_departmentname
    WHERE department_id = p_department_id;

    SELECT ROW_COUNT() AS affected_rows;
END $$
DELIMITER ;

-- Stored Procedure: Delete Department
DELIMITER $$
CREATE PROCEDURE sp_delete_department(
    IN p_department_id INT
)
BEGIN
    DELETE FROM department
    WHERE department_id = p_department_id;

    SELECT ROW_COUNT() AS affected_rows;
END $$
DELIMITER ;

-- Employee Table
CREATE TABLE IF NOT EXISTS employee (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    employee_code VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    department_id INT,
    employment_type VARCHAR(50),
    manager_id INT NULL,
    join_date DATE,
    yoe INT,
    role VARCHAR(50),
    designation_id INT,
    location VARCHAR(255),
    contact_number VARCHAR(20),
    avatar_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_accounts(id),
    FOREIGN KEY (department_id) REFERENCES department(department_id)
);

-- Stored Procedure: Create Employee
DELIMITER $$
CREATE PROCEDURE sp_create_employee(
    IN p_user_id INT,
    IN p_employee_code VARCHAR(50),
    IN p_full_name VARCHAR(255),
    IN p_department_id INT,
    IN p_employment_type VARCHAR(50),
    IN p_manager_id INT,
    IN p_join_date DATE,
    IN p_yoe INT,
    IN p_role VARCHAR(50),
    IN p_designation_id INT,
    IN p_location VARCHAR(255),
    IN p_contact_number VARCHAR(20),
    IN p_avatar_url VARCHAR(255)
)
BEGIN
    INSERT INTO employee (
        user_id, employee_code, full_name, department_id, 
        employment_type, manager_id, join_date, yoe, role, designation_id,
        location, contact_number, avatar_url
    ) VALUES (
        p_user_id, p_employee_code, p_full_name, p_department_id, 
        p_employment_type, p_manager_id, p_join_date, p_yoe, p_role, p_designation_id,
        p_location, p_contact_number, p_avatar_url
    );

    SELECT LAST_INSERT_ID() AS employee_id;
END $$
DELIMITER ;

-- Stored Procedure: Get All Employees
DELIMITER $$
CREATE PROCEDURE sp_get_employees()
BEGIN
    SELECT 
        e.*,
        u.email,
        d.departmentname
    FROM employee e
    LEFT JOIN user_accounts u ON e.user_id = u.id
    LEFT JOIN department d ON e.department_id = d.department_id
    ORDER BY e.employee_id DESC;
END $$
DELIMITER ;

-- Stored Procedure: Get Employee By ID
DELIMITER $$
CREATE PROCEDURE sp_get_employee_by_id(
    IN p_employee_id INT
)
BEGIN
    SELECT 
        e.*,
        u.email,
        d.departmentname
    FROM employee e
    LEFT JOIN user_accounts u ON e.user_id = u.id
    LEFT JOIN department d ON e.department_id = d.department_id
    WHERE e.employee_id = p_employee_id;
END $$
DELIMITER ;

-- Stored Procedure: Update Employee
DELIMITER $$
CREATE PROCEDURE sp_update_employee(
    IN p_employee_id INT,
    IN p_user_id INT,
    IN p_employee_code VARCHAR(50),
    IN p_full_name VARCHAR(255),
    IN p_department_id INT,
    IN p_employment_type VARCHAR(50),
    IN p_manager_id INT,
    IN p_join_date DATE,
    IN p_yoe INT,
    IN p_role VARCHAR(50),
    IN p_designation_id INT,
    IN p_location VARCHAR(255),
    IN p_contact_number VARCHAR(20),
    IN p_avatar_url VARCHAR(255)
)
BEGIN
    UPDATE employee SET
        user_id = p_user_id,
        employee_code = p_employee_code,
        full_name = p_full_name,
        department_id = p_department_id,
        employment_type = p_employment_type,
        manager_id = p_manager_id,
        join_date = p_join_date,
        yoe = p_yoe,
        role = p_role,
        designation_id = p_designation_id,
        location = p_location,
        contact_number = p_contact_number,
        avatar_url = p_avatar_url
    WHERE employee_id = p_employee_id;

    SELECT ROW_COUNT() AS affected_rows;
END $$
DELIMITER ;

-- Stored Procedure: Delete Employee
DELIMITER $$
CREATE PROCEDURE sp_delete_employee(
    IN p_employee_id INT
)
BEGIN
    DELETE FROM employee WHERE employee_id = p_employee_id;
    SELECT ROW_COUNT() AS affected_rows;
END $$
DELIMITER ;
