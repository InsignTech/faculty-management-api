const pool = require('../config/db');

async function check() {
    try {
        const [rows] = await pool.query("SELECT * FROM employee_leaves WHERE emp_id = 1004 ORDER BY month_year DESC, leave_type");
        console.log("All leaves for 1004:");
        console.table(rows);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
check();
