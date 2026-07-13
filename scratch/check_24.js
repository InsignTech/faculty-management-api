const pool = require('../config/db');
async function test() {
    try {
        const [rows] = await pool.query("SELECT * FROM leave_requests WHERE leave_request_id = 24");
        console.log(rows[0]);
    } catch(err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
