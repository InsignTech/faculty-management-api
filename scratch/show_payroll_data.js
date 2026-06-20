const pool = require('../config/db');

async function check() {
    try {
        const [rules] = await pool.execute('SELECT * FROM deduction_rule_master');
        console.log("Deduction Rules:", JSON.stringify(rules, null, 2));

        const [slabs] = await pool.execute('SELECT * FROM profession_tax_slab');
        console.log("Profession Tax Slabs:", JSON.stringify(slabs, null, 2));

        const [periods] = await pool.execute('SELECT * FROM payroll_period');
        console.log("Payroll Periods:", JSON.stringify(periods, null, 2));
    } catch (e) {
        console.error("Error:", e);
    }
    process.exit(0);
}
check();
