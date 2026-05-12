const pool = require('./config/db');

async function getSP() {
    try {
        const [rows] = await pool.query("SHOW CREATE PROCEDURE sp_approve_leave");
        console.log(rows[0]['Create Procedure']);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}

getSP();
