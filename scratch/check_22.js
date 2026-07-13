const pool = require('../config/db');

async function test() {
    try {
        const [rows] = await pool.query(
            "SELECT leave_request_id, is_paid FROM leave_requests WHERE leave_request_id = 22"
        );
        console.log("Request 22 is_paid:", rows[0].is_paid);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
