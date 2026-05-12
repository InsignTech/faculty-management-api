const pool = require('./config/db');

async function migrate() {
    try {
        await pool.query(`
            ALTER TABLE employee 
            ADD COLUMN profile_picture VARCHAR(255) DEFAULT NULL 
            AFTER email
        `);
        console.log('Successfully added profile_picture column to employee table');
    } catch (err) {
        if (err.code === 'ER_DUP_COLUMN_NAME') {
            console.log('Column profile_picture already exists');
        } else {
            console.error('Migration failed:', err);
        }
    } finally {
        process.exit();
    }
}

migrate();
