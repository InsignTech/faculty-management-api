const pool = require('../config/db');

async function test() {
    try {
        console.log("Calling sp_sync_leave_accrual directly...");
        const [rows] = await pool.execute(
            'CALL sp_sync_leave_accrual(?, ?, ?, ?, ?, ?, ?, ?)',
            [1, 'Casual Leave', '07-2026', 2026, 7, 0, false, 1]
        );
        console.log("Procedure Result:", rows);
        const [dbRows] = await pool.query("SELECT * FROM employee_leaves WHERE emp_id = 1 AND month_year = '07-2026'");
        console.log("Database Rows afterwards:", dbRows);
    } catch (err) {
        console.error("Error executing SP:", err);
    } finally {
        process.exit();
    }
}
test();
