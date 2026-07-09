const pool = require('../config/db');

async function migrate() {
    try {
        console.log('Adding is_paid column to leave_requests...');
        await pool.query(`
            ALTER TABLE leave_requests 
            ADD COLUMN is_paid TINYINT NOT NULL DEFAULT 1
        `).catch(err => {
            if (err.code === 'ER_DUP_FIELDNAME') {
                console.log('Column is_paid already exists.');
            } else {
                throw err;
            }
        });
        console.log('Database migration successful.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
