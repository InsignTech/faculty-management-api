const pool = require('../config/db');
const LeaveModel = require('../models/leaveModel');

async function test() {
    try {
        console.log("Setting request 25 back to Pending...");
        await pool.query("UPDATE leave_requests SET status = 'Pending' WHERE leave_request_id = 25");
        
        console.log("Setting attendance for 2026-07-02 back to default (Absent, FullDay, 1.00 deduction)...");
        await pool.query(
            `UPDATE attendance_daily 
             SET status = 'Absent', shift_type = 'FullDay', deduction_days = 1.00, is_leave = 0, leave_shift_type = NULL 
             WHERE employee_id = 4 AND date = '2026-07-02'`
        );

        console.log("Approving request 25 using LeaveModel.action...");
        // requestId, status, approverId, remarks, substituteId
        const result = await LeaveModel.action(25, 'Approved', 999, 'Approved via test script', null);
        console.log("LeaveModel.action Result:", result);

        const [daily] = await pool.query(
            "SELECT * FROM attendance_daily WHERE employee_id = 4 AND date = '2026-07-02'"
        );
        console.log("Attendance Daily Row after LeaveModel.action:", daily[0]);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
