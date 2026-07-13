const pool = require('../config/db');

async function migrate() {
    try {
        console.log('Dropping incorrect unique key idx_emp_leave from employee_leaves...');
        await pool.query('ALTER TABLE employee_leaves DROP INDEX idx_emp_leave');
        console.log('Unique index dropped successfully.');
    } catch (err) {
        console.error('Migration failed:', err.message);
    } finally {
        process.exit();
    }
}
migrate();
