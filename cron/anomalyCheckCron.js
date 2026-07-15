const cron = require('node-cron');
const pool = require('../config/db');
const { sendAttendanceMismatchReport } = require('../utils/emailService');
const debugLog = require('../utils/debugLogger');

// Schedule daily checker to run at 7:30 PM IST
cron.schedule('30 19 * * *', async () => {
    debugLog('⏱️  [CRON] Starting daily attendance anomaly check...', 'INFO');

    try {
        const today = new Date().toISOString().split('T')[0];
        
        // Find anomalies for today
        const [rows] = await pool.query(
            `SELECT
                e.employee_code,
                e.employee_name,
                ad.date,
                ad.first_in_time,
                ad.last_out_time,
                ad.is_late,
                ad.late_minutes,
                ad.is_early_leaving,
                ad.early_minutes,
                ad.deduction_days
            FROM attendance_daily ad
            JOIN employee e ON e.employee_id = ad.employee_id
            WHERE ad.date = CURDATE()
              AND ad.status = 'Present'
              AND (
                  (ad.first_in_time > '09:20:00' AND (COALESCE(ad.is_late, 0) = 0 OR ad.deduction_days = 0))
                  OR
                  (ad.last_out_time < '16:00:00' AND (COALESCE(ad.is_early_leaving, 0) = 0 OR ad.deduction_days = 0))
              )
              AND COALESCE(ad.is_leave, 0) = 0
              AND COALESCE(ad.onduty_shift_type, '') = ''
              AND COALESCE(ad.regularization_shift_type, '') = ''
              AND COALESCE(ad.leave_shift_type, '') = ''
            ORDER BY e.employee_name`
        );

        if (rows.length > 0) {
            debugLog(`⏱️  [CRON] Found ${rows.length} attendance anomalies. Sending email report...`, 'WARNING');
            
            await sendAttendanceMismatchReport({
                toEmails: ['mhdyaseen.official@gmail.com', 'shafeequ.ca@gmail.com'],
                records: rows,
                checkDate: today
            });
            
            debugLog('✅ [CRON] Daily anomaly report email sent successfully!', 'SUCCESS');
        } else {
            debugLog('✅ [CRON] Daily anomaly check completed. No anomalies found.', 'SUCCESS');
        }
    } catch (error) {
        debugLog(`❌ [CRON] Daily anomaly checker failed: ${error.message}`, 'ERROR');
    }
}, {
    scheduled: true,
    timezone: "Asia/Kolkata"
});

debugLog('🕒 [CRON] Attendance anomaly cron job initialized and scheduled for 07:30 PM daily.', 'INFO');

module.exports = cron;
