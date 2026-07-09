const pool = require('../config/db');

async function test() {
    try {
        const [rows] = await pool.query("DESCRIBE attendance_detail_log");
        console.log("Current attendance_detail_log schema:");
        console.table(rows);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
