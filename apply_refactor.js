const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

async function applyRefactor() {
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME,
        multipleStatements: true
    });

    try {
        console.log('Reading Refactor SQL file...');
        const sqlPath = path.join(__dirname, 'db', 'refactor_attendance_schema.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');

        console.log('Applying schema changes...');
        await connection.query(sql);
        console.log('Successfully refactored attendance_daily table!');
    } catch (error) {
        console.error('Error applying refactor:', error);
    } finally {
        await connection.end();
        process.exit();
    }
}

applyRefactor();
