const pool = require('../config/db');

async function test() {
    try {
        const [rows] = await pool.query("SHOW CREATE PROCEDURE sp_approve_leave");
        const definition = rows[0]['Create Procedure'];
        console.log("Does loaded SP contain 'is_paid'?", definition.includes('is_paid'));
        console.log("Does loaded SP contain 'v_is_paid'?", definition.includes('v_is_paid'));
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
