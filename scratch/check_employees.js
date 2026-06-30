const pool = require('../config/db');

async function main() {
    try {
        const [rows] = await pool.query(`
            SELECT employee_id, employee_code, employee_name FROM employee
        `);
        console.log('All employees in DB:');
        console.log(rows);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
