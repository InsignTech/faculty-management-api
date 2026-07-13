const pool = require('../config/db');

async function test() {
    try {
        const [emp] = await pool.query("SELECT * FROM employee WHERE employee_id = 4");
        console.log("Employee 4 details:", emp[0]);
        const [shift] = await pool.query("SELECT * FROM shift_master WHERE employee_id = 4 OR employee_id = -1");
        console.log("Shift configurations:");
        console.table(shift);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
