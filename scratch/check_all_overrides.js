const pool = require('../config/db');
async function test() {
    try {
        const [roles] = await pool.query("SELECT * FROM leave_policy_role");
        console.log("All Role Overrides:");
        console.table(roles);
        const [emps] = await pool.query("SELECT * FROM leave_policy_employee");
        console.log("All Employee Overrides:");
        console.table(emps);
    } catch(err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
