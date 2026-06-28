const pool = require('../config/db');

async function main() {
    try {
        const [rows] = await pool.query(`
            SELECT ss.employee_id, e.employee_name, ss.basic_pay, ss.hra, ss.educational_allowance, ss.special_allowance, ss.naac_allowance, ss.gross_salary
            FROM salary_structure ss
            JOIN employee e ON ss.employee_id = e.employee_id
            WHERE ss.is_current = 1
        `);
        console.log('Current Salary Structures:');
        rows.forEach(r => {
            console.log(`ID: ${r.employee_id}, Name: "${r.employee_name}", Basic: ${r.basic_pay}, HRA: ${r.hra}, Edu: ${r.educational_allowance}, Spec: ${r.special_allowance}, NAAC: ${r.naac_allowance}, Gross: ${r.gross_salary}`);
        });
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
