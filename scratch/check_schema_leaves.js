const pool = require('../config/db');

async function test() {
    try {
        const [rows] = await pool.query("SHOW CREATE TABLE employee_leaves");
        console.log("Table Schema:");
        console.log(rows[0]['Create Table']);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
