const pool = require('../config/db');

async function seed() {
    try {
        console.log("Seeding Deduction Rule Master...");
        const rules = [
            [1, 'EPF', 'Employee Provident Fund', 'percentage', 12.0000, 'basic_pay', null, 15000.00, null, 1, 1, 1, 'Standard EPF contribution'],
            [1, 'ESI', 'Employee State Insurance', 'percentage', 0.7500, 'gross_salary', 21000.00, null, null, 1, 1, 2, 'Standard ESI contribution'],
            [1, 'TDS', 'Tax Deducted at Source', 'manual', null, null, null, null, null, 1, 1, 3, 'Income tax deduction override'],
            [1, 'PT', 'Profession Tax', 'slab', null, null, null, null, null, 1, 1, 4, 'Profession tax based on salary slabs'],
            [1, 'BUS_FEE', 'Bus Fee', 'fixed', null, null, null, null, 0.00, 0, 1, 5, 'Optional bus transportation fee']
        ];
        
        for (const rule of rules) {
            await pool.query(
                `INSERT INTO deduction_rule_master 
                 (organization_id, deduction_code, deduction_name, calc_type, rate, calc_basis, eligibility_ceiling, wage_ceiling, fixed_amount, is_statutory, is_active, display_order, notes)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE is_active = 1`,
                rule
            );
        }

        console.log("Seeding Profession Tax Slabs (KL standard)...");
        const slabs = [
            [1, 'KL', 0.00, 11999.99, 0.00, '2026-01-01', null],
            [1, 'KL', 12000.00, 17999.99, 120.00, '2026-01-01', null],
            [1, 'KL', 18000.00, 29999.99, 180.00, '2026-01-01', null],
            [1, 'KL', 30000.00, 44999.99, 300.00, '2026-01-01', null],
            [1, 'KL', 45000.00, null, 450.00, '2026-01-01', null]
        ];

        for (const slab of slabs) {
            await pool.query(
                `INSERT INTO profession_tax_slab 
                 (organization_id, state_code, min_salary, max_salary, monthly_tax, effective_from, effective_to)
                 VALUES (?, ?, ?, ?, ?, ?, ?)`,
                slab
            );
        }

        console.log("Master data seeded successfully!");
    } catch (e) {
        console.error("Error during seeding:", e);
    }
    process.exit(0);
}
seed();
