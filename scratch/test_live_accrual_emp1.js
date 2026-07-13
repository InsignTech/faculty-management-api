const pool = require('../config/db');
const LeavePolicyModel = require('../models/leavePolicyModel');

async function test() {
    try {
        console.log("Running LIVE accrual for employee 1 for July 2026...");
        const result = await LeavePolicyModel.calculateAccrual(false, '2026-07-01');
        console.log("Done. Checking database rows...");
        const [rows] = await pool.query("SELECT * FROM employee_leaves WHERE emp_id = 1 AND month_year = '07-2026'");
        console.log(rows);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
