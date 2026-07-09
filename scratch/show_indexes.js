const pool = require('../config/db');

async function test() {
    try {
        const [rows] = await pool.query("SHOW INDEX FROM attendance_detail_log");
        console.table(rows);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
