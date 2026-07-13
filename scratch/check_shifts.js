const mysql = require('mysql2/promise');
require('dotenv').config({ path: '../.env' });

async function run() {
    const pool = mysql.createPool({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME
    });

    try {
        console.log('--- Shifts in shift_master ---');
        const [rows] = await pool.query(`
            SELECT 
                employee_id,
                shift_type,
                start_time,
                end_time,
                start_grace_mins,
                end_grace_mins,
                is_active
            FROM shift_master
            WHERE is_active = 1
        `);
        console.log(JSON.stringify(rows, null, 2));

        console.log('\n--- Details of Attendance Daily for LAMIYA on 2026-06-19 ---');
        const [lamiya] = await pool.query(`
            SELECT * FROM attendance_daily 
            WHERE employee_id = 45 AND date = '2026-06-19'
        `);
        console.log(JSON.stringify(lamiya, null, 2));
    } catch (e) {
        console.error(e);
    } finally {
        await pool.end();
    }
}
run();
