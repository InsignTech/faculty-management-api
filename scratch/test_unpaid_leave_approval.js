const pool = require('../config/db');
const LeaveRequestModel = require('../models/leaveRequestModel');

async function test() {
    const conn = await pool.getConnection();
    try {
        console.log("Creating unpaid leave request for employee 1004 on 2026-07-03...");
        await conn.query("DELETE FROM attendance_daily WHERE employee_id = 1004 AND date = '2026-07-03'");
        await conn.query("DELETE FROM leave_requests WHERE employee_id = 1004 AND start_date = '2026-07-03'");
        
        // Insert a raw attendance record representing an Absent day before approval
        await conn.query(
            `INSERT INTO attendance_daily (employee_id, date, status, shift_type, deduction_days) 
             VALUES (1004, '2026-07-03', 'Absent', 'FullDay', 1.00)`
        );

        // Apply for unpaid discretionary leave
        const data = {
            employee_id: 1004,
            leave_type: 'Discretionary Leave',
            start_date: '2026-07-03',
            end_date: '2026-07-03',
            leave_half_type: 'FullDay',
            reason: 'Test unpaid leave',
            attachment_path: 'test.pdf',
            total_days: 1,
            check_balance: false
        };

        await LeaveRequestModel.superAdminCreateLeave(data, 1);

        // Get the inserted request ID
        const [lr] = await conn.query("SELECT leave_request_id FROM leave_requests WHERE employee_id = 1004 AND start_date = '2026-07-03' ORDER BY leave_request_id DESC LIMIT 1");
        const reqId = lr[0].leave_request_id;
        console.log("Request ID:", reqId);

        // No need to approve it manually; superAdminCreateLeave immediately approves it.

        // Query attendance daily
        const [att] = await conn.query("SELECT * FROM attendance_daily WHERE employee_id = 1004 AND date = '2026-07-03'");
        console.log("Attendance Daily after approval:", att[0]);
    } catch (err) {
        console.error(err);
    } finally {
        conn.release();
        process.exit();
    }
}
test();
