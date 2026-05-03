const pool = require('./config/db');

async function checkSP() {
    try {
        const [rows] = await pool.query("SHOW CREATE PROCEDURE sp_apply_leave");
        console.log(rows[0]['Create Procedure']);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit(0);
    }
}

checkSP();
