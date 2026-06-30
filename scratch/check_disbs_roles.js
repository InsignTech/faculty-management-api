const pool = require('../config/db');

async function main() {
    try {
        const [rows] = await pool.query(`
            SELECT sd.disbursement_id, e.employee_id, e.employee_name, e.employee_code, e.employee_type, r.role, d.designation, sd.basic_pay, sd.net_salary
            FROM salary_disbursement sd
            JOIN employee e ON sd.employee_id = e.employee_id
            LEFT JOIN app_role r ON e.role_id = r.role_id
            LEFT JOIN designation d ON e.designation_id = d.designation_id
            WHERE sd.period_id = 1
        `);
        console.log(`Disbursements for Period 1: ${rows.length} rows`);
        console.log(rows.slice(0, 30));
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
