const pool = require('./config/db');
const LeavePolicyModel = require('./models/leavePolicyModel');

async function debug() {
    const empId = 1;
    const targetDate = '2026-06-01';
    console.log(`--- Debugging Accrual for Emp ${empId} on ${targetDate} ---`);
    
    try {
        const effectivePolicy = await LeavePolicyModel.getEffectivePolicy(empId, targetDate);
        if (!effectivePolicy) {
            console.log('❌ NO EFFECTIVE POLICY FOUND for June 1st');
            process.exit(0);
        }
        
        console.log('✅ Policy Found:', effectivePolicy.policy_name);
        const policyValue = effectivePolicy.policy_value || [];
        console.log('Policy Items Count:', policyValue.length);
        
        const result = await LeavePolicyModel.calculateAccrual(true, targetDate);
        const empResult = result.find(r => r.employee_id === empId);
        
        if (empResult) {
            console.log('✅ Employee found in result report:');
            console.log(JSON.stringify(empResult, null, 2));
        } else {
            console.log('❌ Employee NOT found in result report');
        }
        
        process.exit(0);
    } catch (e) {
        console.error('💥 ERROR:', e);
        process.exit(1);
    }
}

debug();
