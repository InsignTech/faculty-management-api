const pool = require('./config/db');

async function migrate() {
    try {
        await pool.query(`
            ALTER TABLE attendance_daily 
            ADD COLUMN is_leave TINYINT DEFAULT 0 AFTER is_regularize_type,
            ADD COLUMN is_leave_type VARCHAR(100) DEFAULT NULL AFTER is_leave,
            ADD COLUMN leave_shift_type ENUM('FullDay', 'FirstHalf', 'SecondHalf') DEFAULT NULL AFTER is_leave_type
        `);
        console.log('Successfully updated attendance_daily table schema');
    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        process.exit();
    }
}

migrate();
