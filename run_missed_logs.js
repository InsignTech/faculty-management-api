const pool = require('./config/db');
const AttendanceModel = require('./models/attendanceModel');

async function run() {
    try {
        console.log("Processing missing attendance logs...");
        const result = await AttendanceModel.processMissedLogs();
        console.log(`Successfully processed ${result.total_processed} rows across ${result.days_processed} day(s).`);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        process.exit(0);
    }
}

run();
