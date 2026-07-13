const pool = require('../config/db');

async function test() {
    try {
        const [glob] = await pool.query("SELECT * FROM leave_policy WHERE active = 1");
        console.log("=== Active Global Policies ===");
        glob.forEach(g => {
            console.log(`Policy ID: ${g.leave_policy_id}, Name: ${g.policy_name}`);
            console.log(JSON.stringify(JSON.parse(g.policy_value), null, 2));
        });

        const [role] = await pool.query("SELECT * FROM leave_policy_role WHERE active = 1");
        console.log("\n=== Active Role Policies ===");
        role.forEach(r => {
            console.log(`Role ID: ${r.role_id}`);
            console.log(JSON.stringify(JSON.parse(r.policy_value), null, 2));
        });

        const [emp] = await pool.query("SELECT * FROM leave_policy_employee WHERE active = 1");
        console.log("\n=== Active Employee Policies ===");
        emp.forEach(e => {
            console.log(`Employee ID: ${e.employee_id}`);
            console.log(JSON.stringify(JSON.parse(e.policy_value), null, 2));
        });
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
