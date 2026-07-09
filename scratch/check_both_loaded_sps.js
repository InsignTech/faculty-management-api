const pool = require('../config/db');

async function check() {
    try {
        const [rowsApprove] = await pool.query("SHOW CREATE PROCEDURE sp_approve_leave");
        console.log("=== sp_approve_leave loaded definition ===");
        console.log(rowsApprove[0]['Create Procedure']);

        const [rowsProcess] = await pool.query("SHOW CREATE PROCEDURE sp_process_attendance");
        console.log("\n=== sp_process_attendance loaded definition ===");
        console.log(rowsProcess[0]['Create Procedure']);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
check();
