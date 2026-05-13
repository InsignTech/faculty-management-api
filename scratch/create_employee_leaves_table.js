const mysql = require('mysql2/promise');
require('dotenv').config();

async function createTable() {
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME
    });

    try {
        const sql = `
            CREATE TABLE IF NOT EXISTS employee_leaves (
                leave_id INT AUTO_INCREMENT PRIMARY KEY,
                emp_id INT NOT NULL,
                leave_type VARCHAR(100) NOT NULL,
                opening_leave DECIMAL(10, 2) DEFAULT 0.00,
                credited_count DECIMAL(10, 2) DEFAULT 0.00,
                leaves_taken DECIMAL(10, 2) DEFAULT 0.00,
                total_leaves DECIMAL(10, 2) DEFAULT 0.00,
                balance_leave DECIMAL(10, 2) DEFAULT 0.00,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY (emp_id, leave_type),
                FOREIGN KEY (emp_id) REFERENCES employee(employee_id) ON DELETE CASCADE
            );
        `;
        await connection.query(sql);
        console.log('Table employee_leaves created successfully');
    } catch (error) {
        console.error('Error creating table:', error);
    } finally {
        await connection.end();
    }
}

createTable();
