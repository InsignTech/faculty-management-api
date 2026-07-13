const pool = require('../config/db');
const LeavePolicyModel = require('../models/leavePolicyModel');

async function test() {
    try {
        console.log("Running test accrual for employee 1 for July 2026...");
        const result = await LeavePolicyModel.calculateAccrual(true, '2026-07-01');
        const emp1 = result.find(r => r.employee_id === 1);
        console.log("Employee 1 Credits:", JSON.stringify(emp1, null, 2));
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
