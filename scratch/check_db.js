const pool = require('../config/db');
const PayrollModel = require('../models/payrollModel');

async function main() {
    try {
        console.log('--- Inspecting payroll_workflow_config ---');
        const [config] = await pool.query("SELECT * FROM payroll_workflow_config");
        console.log('Configs:', config);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
