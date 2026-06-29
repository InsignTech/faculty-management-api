const pool = require('../config/db');

async function main() {
    try {
        const [rows] = await pool.query(`
            SELECT * FROM attendance_daily 
            WHERE employee_id = 1004 AND date BETWEEN '2026-06-01' AND '2026-06-30'
        `);
        console.log('Attendance records for employee 1004:');
        console.log(rows);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
