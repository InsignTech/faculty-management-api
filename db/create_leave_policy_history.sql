
CREATE TABLE IF NOT EXISTS leave_policy_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    leave_policy_id INT NOT NULL,
    policy_name VARCHAR(255),
    policy_value JSON,
    start_date DATE,
    end_date DATE,
    changed_by VARCHAR(100),
    changed_on DATETIME DEFAULT CURRENT_TIMESTAMP,
    change_type ENUM('Created', 'Updated', 'Deleted', 'Activated')
);
