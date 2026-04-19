const pool = require('./config/db');
async function showSp() {
    try {
        const [rows] = await pool.query("SHOW CREATE PROCEDURE sp_process_attendance_logs");
        console.log("DB PROCEDURE MATCHES PASTED SP?: " + rows[0]['Create Procedure'].includes("DATE(punch_time)"));
        console.log("DEFINER:", rows[0]['Create Procedure'].split(' PROCEDURE')[0]);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        process.exit(0);
    }
}
showSp();
