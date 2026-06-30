const XLSX = require('xlsx');
const path = require('path');
const pool = require('../config/db');

async function main() {
    try {
        const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
        const workbook = XLSX.readFile(filePath);

        const salarySheet = workbook.Sheets['APRIL SALARY'];
        const remuSheet = workbook.Sheets['APRIL  REMU'];

        const salaryData = XLSX.utils.sheet_to_json(salarySheet, { header: 1 });
        const remuData = XLSX.utils.sheet_to_json(remuSheet, { header: 1 });

        const [dbEmployees] = await pool.query('SELECT employee_id, employee_name, employee_code, designation_id, department_id FROM employee');

        const normalize = (name) => name ? name.toLowerCase().replace(/[^a-z0-9]/g, '') : '';

        console.log('--- Matching APRIL SALARY employees to DB ---');
        for (let i = 4; i < salaryData.length; i++) {
            const row = salaryData[i];
            if (!row || !row[1] || row[1] === 'Prepared By: ' || row[0] === null) continue;
            const name = row[1];
            const norm = normalize(name);
            const matches = dbEmployees.filter(e => normalize(e.employee_name).includes(norm) || norm.includes(normalize(e.employee_name)));
            console.log(`Excel name: "${name}" -> DB Matches:`, matches.map(m => `${m.employee_name} (ID: ${m.employee_id}, Code: ${m.employee_code})`).join(', ') || 'NONE');
        }

        console.log('\n--- Matching APRIL REMU employees to DB ---');
        for (let i = 3; i < remuData.length; i++) {
            const row = remuData[i];
            if (!row || !row[1] || row[0] === null) continue;
            const name = row[1];
            const norm = normalize(name);
            const matches = dbEmployees.filter(e => normalize(e.employee_name).includes(norm) || norm.includes(normalize(e.employee_name)));
            console.log(`Excel name: "${name}" -> DB Matches:`, matches.map(m => `${m.employee_name} (ID: ${m.employee_id}, Code: ${m.employee_code})`).join(', ') || 'NONE');
        }

    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
