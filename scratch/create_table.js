const pool = require('../config/db');
const fs = require('fs');
const path = require('path');

async function createTable() {
    try {
        const sql = fs.readFileSync(path.join(__dirname, '../db/create_attendance_punches.sql'), 'utf8');
        await pool.query(sql);
        console.log('attendance_punches table created successfully.');
    } catch (err) {
        console.error('Error creating table:', err);
    } finally {
        process.exit();
    }
}

createTable();
