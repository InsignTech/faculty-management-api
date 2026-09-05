const pool = require('../config/db');

async function migrate() {
    try {
        const [columns] = await pool.query("SHOW COLUMNS FROM attendance_regularization LIKE 'batch_id'");
        if (columns.length === 0) {
            console.log('Adding batch_id column...');
            await pool.query("ALTER TABLE attendance_regularization ADD COLUMN batch_id VARCHAR(64) DEFAULT NULL AFTER id, ADD KEY idx_ar_batch_id (batch_id)");
            console.log('Column batch_id added successfully.');
        } else {
            console.log('batch_id column already exists.');
        }
        
        const [res] = await pool.query("UPDATE attendance_regularization SET batch_id = CONCAT('legacy-', id) WHERE batch_id IS NULL");
        console.log('Backfilled legacy rows:', res.affectedRows);
        
        const [check] = await pool.query("DESCRIBE attendance_regularization");
        console.log('Updated columns in attendance_regularization:', check.map(c => c.Field).join(', '));
        process.exit(0);
    } catch (e) {
        console.error('Migration error:', e);
        process.exit(1);
    }
}

migrate();
