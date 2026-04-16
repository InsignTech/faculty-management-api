const cron = require('node-cron');
const AttendanceModel = require('../models/attendanceModel');
const debugLog = require('../utils/debugLogger');

// Schedule tasks to be run on the server.
// The schedule: '59 23 * * *' translates to 11:59 PM every day.
cron.schedule('59 23 * * *', async () => {
    debugLog('⏱️  [CRON] Starting nightly attendance processing...', 'INFO');
    
    try {
        // Format today's date as YYYY-MM-DD
        const today = new Date();
        const dateString = today.toISOString().split('T')[0];
        
        debugLog(`⏱️  [CRON] Processing logs for date: ${dateString}`, 'INFO');
        
        const result = await AttendanceModel.processLogs(dateString);
        
        debugLog(`✅ [CRON] Nightly attendance processing completed! Processed rows: ${result?.processed_rows || 0}`, 'SUCCESS');
    } catch (error) {
        debugLog(`❌ [CRON] Nightly attendance processing failed: ${error.message}`, 'ERROR');
    }
}, {
    scheduled: true,
    timezone: "Asia/Kolkata" // Adjust timezone based on organization's location.
});

debugLog('🕒 [CRON] Attendance cron job initialized and scheduled for 11:59 PM daily.', 'INFO');

module.exports = cron;
