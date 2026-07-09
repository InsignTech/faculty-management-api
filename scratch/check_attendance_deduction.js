const pool = require('../config/db');

async function test() {
    try {
        const [rows] = await pool.query(
            "SELECT * FROM attendance_daily WHERE employee_id = 1004 AND date IN ('2026-07-01', '2026-07-02')"
        );
        console.log("Attendance Daily:");
        console.table(rows);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
