const pool = require('../config/db');

async function test() {
    try {
        const [rows] = await pool.query(
            "SELECT leave_request_id, employee_id, leave_type, is_paid, status, start_date, end_date, total_days FROM leave_requests ORDER BY leave_request_id DESC LIMIT 5"
        );
        console.log("Recent Leave Requests:");
        console.table(rows);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
