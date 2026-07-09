const pool = require('../config/db');
const LeaveRequestModel = require('../models/leaveRequestModel');

async function test() {
    try {
        console.log("Checking balance for 1004 on 2026-07-01...");
        const result = await LeaveRequestModel.getLeaveBalance(1004, new Date('2026-07-01'));
        console.log("Balances:");
        console.table(result);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
