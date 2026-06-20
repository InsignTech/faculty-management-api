const pool = require('../config/db');

async function seedStructures() {
    try {
        const [existing] = await pool.execute('SELECT COUNT(*) AS count FROM salary_structure');
        console.log("Existing structures count:", existing[0].count);
        
        if (existing[0].count === 0) {
            console.log("No salary structures found. Fetching employees to seed...");
            const [employees] = await pool.execute('SELECT employee_id, employee_name, basic_pay FROM employee WHERE active = 1');
            console.log(`Found ${employees.length} active employees.`);
            
            for (const emp of employees) {
                const basic = parseFloat(emp.basic_pay) || 15000.00;
                // Calculate components matching the style:
                // HRA: ~40% of basic
                // Educational allowance: ~10% of basic
                // Special allowance: ~5% of basic
                // NAAC allowance: fixed 500 or 750 or 2000
                const hra = Math.round(basic * 0.40);
                const edu = Math.round(basic * 0.10);
                const spec = Math.round(basic * 0.05);
                const naac = 750.00; // standard NAAC allowance
                
                await pool.execute(
                    `INSERT INTO salary_structure 
                     (employee_id, basic_pay, hra, educational_allowance, special_allowance, naac_allowance, effective_from, is_current, created_by)
                     VALUES (?, ?, ?, ?, ?, ?, '2026-01-01', 1, 'system')`,
                    [emp.employee_id, basic, hra, edu, spec, naac]
                );
            }
            console.log("Successfully seeded salary structures for all active employees!");
        } else {
            console.log("Salary structures already present.");
        }
    } catch (e) {
        console.error("Error seeding salary structures:", e);
    }
    process.exit(0);
}
seedStructures();
