const pool = require('../config/db');

async function test() {
    try {
        const [requests] = await pool.query(
            `SELECT leave_request_id, employee_id, leave_type, is_paid, status, start_date, end_date, total_days 
             FROM leave_requests 
             WHERE status = 'Approved' AND is_paid = 0
             ORDER BY leave_request_id DESC LIMIT 5`
        );
        console.log("Approved Unpaid Leave Requests:");
        console.table(requests);

        for (const req of requests) {
            console.log(`\nChecking attendance for request ${req.leave_request_id} (Employee ${req.employee_id}, Dates: ${req.start_date} to ${req.end_date}):`);
            const [attendance] = await pool.query(
                `SELECT date, status, shift_type, deduction_days, is_leave, leave_shift_type, regularization_shift_type, onduty_shift_type
                 FROM attendance_daily 
                 WHERE employee_id = ? AND date BETWEEN ? AND ?`,
                [req.employee_id, req.start_date, req.end_date]
            );
            console.table(attendance);
        }
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
