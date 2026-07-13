const pool = require('../config/db');
async function test() {
    try {
        const [emp] = await pool.query("SELECT * FROM employee WHERE employee_id = 1004");
        const roleId = emp[0].role_id;
        console.log("Employee details:", emp[0]);
        const [rolePolicy] = await pool.execute('SELECT * FROM leave_policy_role WHERE role_id = ?', [roleId]);
        console.log("Role Policy Overrides:", rolePolicy);
        const [empPolicy] = await pool.execute('SELECT * FROM leave_policy_employee WHERE employee_id = ?', [1004]);
        console.log("Employee Policy Overrides:", empPolicy);
    } catch(err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
