const pool = require('../config/db');

async function test() {
    try {
        console.log("Setting request 24 back to Pending...");
        await pool.query("UPDATE leave_requests SET status = 'Pending' WHERE leave_request_id = 24");
        
        console.log("Setting attendance for 2026-06-30 back to default (Absent, FullDay, 1.00 deduction)...");
        await pool.query(
            `UPDATE attendance_daily 
             SET status = 'Absent', shift_type = 'FullDay', deduction_days = 1.00, is_leave = 0, leave_shift_type = NULL 
             WHERE employee_id = 1004 AND date = '2026-06-30'`
        );

        console.log("Approving request 24 using sp_approve_leave...");
        const [result] = await pool.query("CALL sp_approve_leave(24, 999, 'Approved', '', null)");
        console.log("Procedure Result:", result);

        const [daily] = await pool.query(
            "SELECT * FROM attendance_daily WHERE employee_id = 1004 AND date = '2026-06-30'"
        );
        console.log("Attendance Daily Row after manual approval:", daily[0]);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
