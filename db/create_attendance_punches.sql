CREATE TABLE IF NOT EXISTS attendance_punches (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    device_sn VARCHAR(100) NOT NULL,
    employee_code VARCHAR(100) NOT NULL,
    punch_time DATETIME NOT NULL,
    punch_state VARCHAR(20),
    verify_mode VARCHAR(20),
    work_code VARCHAR(50),
    raw_data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_emp_time (employee_code, punch_time),
    INDEX idx_device_sn (device_sn)
);
