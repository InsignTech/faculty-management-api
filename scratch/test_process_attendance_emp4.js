const pool = require('../config/db');

async function test() {
    try {
        console.log("Calling sp_process_attendance for 2026-07-02...");
        await pool.query("CALL sp_process_attendance('2026-07-02')");
        
        const [daily] = await pool.query(
            "SELECT * FROM attendance_daily WHERE employee_id = 4 AND date = '2026-07-02'"
        );
        console.log("Attendance Daily Row after sp_process_attendance:", daily[0]);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
