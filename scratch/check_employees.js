const pool = require('../config/db');

async function main() {
    try {
        const [rows] = await pool.query(`
            SELECT employee_id, employee_code, employee_name, employee_type, designation_id, department_id
            FROM employee 
            WHERE employee_name LIKE '%Ashraf%' OR employee_name LIKE '%Amritha%' OR employee_name LIKE '%Aslam%'
        `);
        console.log('Matching Employees:');
        console.log(rows);

        const [designations] = await pool.query('SELECT * FROM designation');
        console.log('\nDesignations:');
        console.log(designations);

        const [departments] = await pool.query('SELECT * FROM department');
        console.log('\nDepartments:');
        console.log(departments);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
