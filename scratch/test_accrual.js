const pool = require('../config/db');
const LeavePolicyModel = require('../models/leavePolicyModel');

async function test() {
    try {
        const [employees] = await pool.execute('SELECT employee_id, employee_name FROM employee WHERE employee_id = 1004');
        const emp = employees[0];
        const empId = emp.employee_id;
        const currentMonth = 7;
        const currentYear = 2026;
        const sqlTargetDate = '2026-07-01';
        const monthYear = '07-2026';
        
        const effectivePolicy = await LeavePolicyModel.getEffectivePolicy(empId, sqlTargetDate);
        console.log("Effective Policy Value:", JSON.stringify(effectivePolicy.policy_value, null, 2));

        for (const item of effectivePolicy.policy_value) {
            const freq = item.creditFrequency || item.cappingType;
            let creditAmount = 0;
            if (freq === 'Monthly') {
                creditAmount = parseFloat(item.cappingCount || 0);
            }
            console.log(`Type: ${item.leaveType}, freq: ${freq}, cappingCount: ${item.cappingCount}, calculated creditAmount: ${creditAmount}`);
        }
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
