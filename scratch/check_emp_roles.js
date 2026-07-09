const pool = require('../config/db');
async function test() {
    try {
        const [rows] = await pool.query("SELECT role_id, COUNT(*) as count FROM employee GROUP BY role_id");
        console.log("Employees by role:");
        console.table(rows);
        const [emp1] = await pool.query("SELECT employee_id, role_id, employee_name FROM employee WHERE employee_id = 1");
        console.log("Employee 1 Details:", emp1[0]);
    } catch(err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
