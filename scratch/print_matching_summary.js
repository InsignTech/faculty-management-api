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

        const salaryNames = new Set();
        for (let i = 4; i < salaryData.length; i++) {
            const row = salaryData[i];
            if (row && row[1] && row[0] !== null && row[1] !== 'Prepared By: ') {
                salaryNames.add(row[1].trim().toLowerCase().replace(/[^a-z0-9]/g, ''));
            }
        }

        const remuNames = new Set();
        for (let i = 3; i < remuData.length; i++) {
            const row = remuData[i];
            if (row && row[1] && row[0] !== null) {
                remuNames.add(row[1].trim().toLowerCase().replace(/[^a-z0-9]/g, ''));
            }
        }

        const [dbEmployees] = await pool.query(`
            SELECT e.employee_id, e.employee_code, e.employee_name, r.role, d.designation
            FROM employee e
            LEFT JOIN app_role r ON e.role_id = r.role_id
            LEFT JOIN designation d ON e.designation_id = d.designation_id
        `);

        console.log('--- Database Employee Categorization Summary ---');
        let matchedSalary = 0;
        let matchedRemu = 0;
        let unmatched = [];

        dbEmployees.forEach(e => {
            const norm = e.employee_name.trim().toLowerCase().replace(/[^a-z0-9]/g, '');
            let isSalary = false;
            let isRemu = false;

            // Check direct or partial match
            for (const sName of salaryNames) {
                if (norm.includes(sName) || sName.includes(norm)) {
                    isSalary = true;
                    break;
                }
            }

            for (const rName of remuNames) {
                if (norm.includes(rName) || rName.includes(norm)) {
                    isRemu = true;
                    break;
                }
            }

            if (isSalary && isRemu) {
                console.log(`[BOTH] ${e.employee_name} (ID: ${e.employee_id}, Role: ${e.role}, Des: ${e.designation})`);
            } else if (isSalary) {
                matchedSalary++;
                // console.log(`[SALARY] ${e.employee_name} (ID: ${e.employee_id}, Role: ${e.role})`);
            } else if (isRemu) {
                matchedRemu++;
                // console.log(`[REMU] ${e.employee_name} (ID: ${e.employee_id}, Role: ${e.role})`);
            } else {
                unmatched.push(e);
            }
        });

        console.log(`Matched Salary sheet: ${matchedSalary}`);
        console.log(`Matched Remu sheet: ${matchedRemu}`);
        console.log(`Unmatched: ${unmatched.length}`);
        console.log('\n--- Unmatched Employees Details ---');
        unmatched.forEach(e => {
            console.log(`- ${e.employee_name} (ID: ${e.employee_id}, Role: ${e.role}, Designation: ${e.designation})`);
        });

    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
