const pool = require('../config/db');

async function test() {
    try {
        const [daily] = await pool.query(
            "SELECT * FROM attendance_daily WHERE employee_id = 4 AND date = '2026-07-02'"
        );
        console.log("Employee 4 Attendance Daily Row on 2026-07-02:");
        console.log(daily[0]);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
