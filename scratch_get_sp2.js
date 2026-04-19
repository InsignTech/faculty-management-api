const pool = require('./config/db');
async function showSp() {
    try {
        const [rows] = await pool.query("SHOW CREATE PROCEDURE sp_process_attendance_logs");
        console.log("PROCEDURE:\n" + rows[0]['Create Procedure']);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        process.exit(0);
    }
}
showSp();
