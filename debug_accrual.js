const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
dotenv.config();

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
});

async function test() {
    const targetDate = '2026-05-14';
    const now = new Date(targetDate);
    const currentMonth = now.getMonth() + 1;
    const currentYear = now.getFullYear();
    const monthYear = `${String(currentMonth).padStart(2, '0')}-${currentYear}`;

    console.log(`Testing Accrual for ${monthYear}`);

    const [employees] = await pool.execute('SELECT employee_id, employee_name FROM employee WHERE active = 1');
    console.log(`Found ${employees.length} active employees`);

    const [globalPolicies] = await pool.execute(`
      SELECT *, policy_value 
      FROM leave_policy 
      ORDER BY active DESC, 
               (CURDATE() BETWEEN start_date AND COALESCE(end_date, '9999-12-31')) DESC, 
               start_date DESC 
      LIMIT 1
    `);

    if (globalPolicies.length === 0) {
        console.log("No global policy found!");
        return;
    }

    console.log(`Using Policy: ${globalPolicies[0].policy_name}`);

    // Test for first employee
    const emp = employees[0];
    const policyValue = globalPolicies[0].policy_value || [];
    console.log(`Processing Emp: ${emp.employee_name}`);

    for (const item of policyValue) {
        console.log(`- Leave Type: ${item.leaveType} (${item.creditFrequency})`);
        // ... simplified sync check ...
    }

    process.exit(0);
}

test();
