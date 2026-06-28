const pool = require('../config/db');

async function main() {
    try {
        console.log('--- Employee Types & Counts ---');
        const [empTypes] = await pool.query('SELECT employee_type, COUNT(*) as count FROM employee GROUP BY employee_type');
        console.log(empTypes);

        console.log('\n--- Sample Employee Fields ---');
        const [emps] = await pool.query('SELECT employee_id, employee_code, employee_name, employee_type, designation_id, department_id, active FROM employee LIMIT 5');
        console.log(emps);

        console.log('\n--- Sample Salary Structures ---');
        const [structs] = await pool.query('SELECT * FROM salary_structure LIMIT 3');
        console.log(structs);

        console.log('\n--- Sample Disbursements ---');
        const [disbs] = await pool.query('SELECT * FROM salary_disbursement LIMIT 3');
        console.log(disbs);

        console.log('\n--- Sample Payroll Periods ---');
        const [periods] = await pool.query('SELECT * FROM payroll_period');
        console.log(periods);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
