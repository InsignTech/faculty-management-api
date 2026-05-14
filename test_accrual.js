const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const LeavePolicyModel = require('./models/leavePolicyModel');

async function test() {
    const targetDate = '2026-05-14';
    console.log(`Testing Accrual for ${targetDate}`);
    
    try {
        const report = await LeavePolicyModel.calculateAccrual(true, targetDate);
        console.log("Report Length:", report.length);
        if (report.length > 0) {
            console.log("First Employee Sample:", JSON.stringify(report[0], null, 2));
        }
    } catch (e) {
        console.error(e);
    }
    process.exit(0);
}

test();
