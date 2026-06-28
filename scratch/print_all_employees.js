const pool = require('../config/db');

async function main() {
    try {
        const [rows] = await pool.query(`
            SELECT e.employee_id, e.employee_code, e.employee_name, e.employee_type, r.role, d.designation, e.basic_pay, dept.departmentname
            FROM employee e
            LEFT JOIN app_role r ON e.role_id = r.role_id
            LEFT JOIN designation d ON e.designation_id = d.designation_id
            LEFT JOIN department dept ON e.department_id = dept.department_id
            ORDER BY e.employee_id
        `);
        console.log(`Total employees: ${rows.length}`);
        console.log(JSON.stringify(rows, null, 2));
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
