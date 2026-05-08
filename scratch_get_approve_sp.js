const pool = require('./config/db');
async function getSp() {
    try {
        const [rows] = await pool.query("SHOW CREATE PROCEDURE sp_approve_leave");
        console.log("PROCEDURE DEFINITION:");
        console.log(rows[0]['Create Procedure']);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        process.exit(0);
    }
}
getSp();
