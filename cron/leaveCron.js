const cron = require('node-cron');
const LeavePolicyModel = require('../models/leavePolicyModel');
const debugLog = require('../utils/debugLogger');

// Schedule leave accrual to run on the 1st of every month at 12:05 AM.
// The schedule: '5 0 1 * *' translates to 12:05 AM on the 1st day of every month.
cron.schedule('5 0 1 * *', async () => {
    debugLog('⏱️  [CRON] Starting monthly leave accrual calculation...', 'INFO');
    
    try {
        await LeavePolicyModel.calculateAccrual();
        debugLog('✅ [CRON] Monthly leave accrual calculation completed successfully.', 'SUCCESS');
    } catch (error) {
        debugLog(`❌ [CRON] Monthly leave accrual calculation failed: ${error.message}`, 'ERROR');
    }
}, {
    scheduled: true,
    timezone: "Asia/Kolkata"
});

debugLog('🕒 [CRON] Leave accrual cron job initialized and scheduled for the 1st of every month at 12:05 AM.', 'INFO');

module.exports = cron;
