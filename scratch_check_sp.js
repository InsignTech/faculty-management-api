const pool = require('./config/db');
async function check() {
  try {
    const [rows] = await pool.query("SHOW PROCEDURE STATUS WHERE Name IN ('sp_process_attendance', 'sp_process_attendance_logs')");
    console.log(rows);
  } catch (e) {
    console.error(e);
  } finally {
    process.exit(0);
  }
}
check();
