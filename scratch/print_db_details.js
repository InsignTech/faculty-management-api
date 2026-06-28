const pool = require('../config/db');

async function main() {
    try {
        const [rows] = await pool.query(`
            SELECT e.employee_id, e.employee_code, e.employee_name, e.joining_date, ss.basic_pay, r.role
            FROM employee e
            LEFT JOIN salary_structure ss ON e.employee_id = ss.employee_id AND ss.is_current = 1
            LEFT JOIN app_role r ON e.role_id = r.role_id
            ORDER BY ss.basic_pay DESC, e.joining_date ASC
        `);
        console.log('Employee details in DB sorted by basic pay:');
        rows.forEach(r => {
            console.log(`ID: ${r.employee_id}, Code: ${r.employee_code}, Name: "${r.employee_name}", JoiningDate: ${r.joining_date}, BasicPay: ${r.basic_pay}, Role: ${r.role}`);
        });
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
