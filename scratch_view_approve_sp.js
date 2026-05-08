const pool = require('./config/db');
async function showSp() {
    try {
        const [rows] = await pool.query("SHOW CREATE PROCEDURE sp_approve_leave");
        console.log(rows[0]['Create Procedure']);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        process.exit(0);
    }
}
showSp();
