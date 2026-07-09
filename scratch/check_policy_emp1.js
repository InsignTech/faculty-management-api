const pool = require('../config/db');
const LeavePolicyModel = require('../models/leavePolicyModel');
async function test() {
    try {
        const policy = await LeavePolicyModel.getEffectivePolicy(1, '2026-07-01');
        console.log("Shafeek Policy:", JSON.stringify(policy.policy_value, null, 2));
    } catch(err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
