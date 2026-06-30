const pool = require('../config/db');

async function main() {
    try {
        const [rows] = await pool.query(`
            SELECT edc.employee_id, e.employee_name, drm.deduction_code, edc.is_applicable
            FROM employee_deduction_config edc
            JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
            JOIN employee e ON edc.employee_id = e.employee_id
            WHERE edc.is_applicable = 1
        `);
        console.log('Active Deduction Configs for Employees:');
        console.log(rows);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
