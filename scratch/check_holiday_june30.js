const pool = require('../config/db');

async function test() {
    try {
        const [holiday] = await pool.query(
            "SELECT * FROM holiday_master WHERE '2026-06-30' BETWEEN holiday_start_date AND holiday_end_date"
        );
        console.log("Holiday:", holiday);
        
        const [daily] = await pool.query(
            "SELECT * FROM attendance_daily WHERE employee_id = 1004 AND date = '2026-06-30'"
        );
        console.log("Attendance Daily Row:", daily[0]);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
