const pool = require('../config/db');

async function check() {
    try {
        const [rows] = await pool.execute("SELECT ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'staffdesk' AND ROUTINE_TYPE = 'PROCEDURE'");
        console.log("Existing Stored Procedures:");
        console.log(rows.map(r => r.ROUTINE_NAME));
    } catch (e) {
        console.error("Error:", e);
    }
    process.exit(0);
}
check();
