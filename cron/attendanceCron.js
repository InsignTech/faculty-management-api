const cron = require('node-cron');
const AttendanceModel = require('../models/attendanceModel');
const debugLog = require('../utils/debugLogger');

// Schedule tasks to be run on the server.
// The schedule: '59 23 * * *' translates to 11:59 PM every day.
cron.schedule('59 23 * * *', async () => {
    debugLog('⏱️  [CRON] Starting nightly attendance processing...', 'INFO');
    
    try {
        debugLog(`⏱️  [CRON] Checking for missing log days up to today...`, 'INFO');
        
        const result = await AttendanceModel.processMissedLogs();
        
        debugLog(`✅ [CRON] Nightly attendance processing completed! Processed ${result.total_processed} rows across ${result.days_processed} day(s).`, 'SUCCESS');
    } catch (error) {
        debugLog(`❌ [CRON] Nightly attendance processing failed: ${error.message}`, 'ERROR');
    }
}, {
    scheduled: true,
    timezone: "Asia/Kolkata" // Adjust timezone based on organization's location.
});

debugLog('🕒 [CRON] Attendance cron job initialized and scheduled for 11:59 PM daily.', 'INFO');

module.exports = cron;
