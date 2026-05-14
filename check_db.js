const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'admin',
    password: 'mysqladmin',
    database: 'staffdesk',
});

async function test() {
    try {
        const [employees] = await pool.execute('SELECT employee_id, employee_name, active FROM employee');
        console.log("Employees:", JSON.stringify(employees, null, 2));
        
        const [policies] = await pool.execute('SELECT leave_policy_id, policy_name, active FROM leave_policy');
        console.log("Policies:", JSON.stringify(policies, null, 2));

        const [settings] = await pool.execute('SELECT * FROM settings WHERE settings_key = "leave_year_start_month"');
        console.log("Settings:", JSON.stringify(settings, null, 2));
    } catch (e) {
        console.error(e);
    }
    process.exit(0);
}

test();
