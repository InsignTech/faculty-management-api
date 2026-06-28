const pool = require('../config/db');

async function main() {
    try {
        const [roles] = await pool.query('SELECT * FROM app_role');
        console.log('App Roles:');
        console.log(roles);

        const [empRoles] = await pool.query(`
            SELECT e.employee_id, e.employee_name, e.employee_code, r.role, d.designation, dept.departmentname
            FROM employee e
            LEFT JOIN app_role r ON e.role_id = r.role_id
            LEFT JOIN designation d ON e.designation_id = d.designation_id
            LEFT JOIN department dept ON e.department_id = dept.department_id
            LIMIT 20
        `);
        console.log('\nEmployees with Roles & Designations (sample):');
        console.log(empRoles);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
