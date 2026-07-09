const pool = require('../config/db');
async function test() {
    try {
        const [rows] = await pool.query(
            "SELECT * FROM leave_requests WHERE employee_id = 1004 AND '2026-06-30' BETWEEN start_date AND end_date"
        );
        console.table(rows);
    } catch(err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
