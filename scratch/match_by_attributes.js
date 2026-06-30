const XLSX = require('xlsx');
const path = require('path');
const pool = require('../config/db');

async function main() {
    try {
        const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
        const workbook = XLSX.readFile(filePath);
        const salarySheet = workbook.Sheets['APRIL SALARY'];
        const salaryData = XLSX.utils.sheet_to_json(salarySheet, { header: 1 });

        const [dbEmployees] = await pool.query(`
            SELECT e.employee_id, e.employee_code, e.employee_name, e.joining_date, ss.basic_pay, r.role
            FROM employee e
            LEFT JOIN salary_structure ss ON e.employee_id = ss.employee_id AND ss.is_current = 1
            LEFT JOIN app_role r ON e.role_id = r.role_id
        `);

        console.log('--- Matching Anonymized Excel Rows to DB by Joining Date & Basic Pay ---');
        for (let i = 4; i < 14; i++) {
            const row = salaryData[i];
            if (!row) continue;
            const slNo = row[0];
            const name = row[1];
            const joinDate = row[2]; // string in Excel
            const basicPay = parseFloat(row[4]);

            // Find matching db employee
            const matches = dbEmployees.filter(e => {
                // Parse date
                const dbJoinStr = e.joining_date ? e.joining_date.split('-').reverse().join('.') : ''; // format dd.mm.yyyy or similar
                // Excel joining date could be dd.mm.yyyy
                const cleanJoinDate = joinDate ? joinDate.trim() : '';
                
                // Compare basic pay and date
                const dbBasic = parseFloat(e.basic_pay || 0);
                const payMatch = Math.abs(dbBasic - basicPay) < 1.0;
                
                // Date comparison
                const eJoin = e.joining_date; // yyyy-mm-dd
                let dateMatch = false;
                if (eJoin && cleanJoinDate) {
                    const [d, m, y] = cleanJoinDate.split('.');
                    const formattedExcelDate = `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
                    dateMatch = (eJoin === formattedExcelDate);
                }
                
                return payMatch && dateMatch;
            });

            console.log(`Excel Row ${slNo}: name="${name}", joinDate="${joinDate}", basicPay=${basicPay} -> DB Matches:`, matches.map(m => `${m.employee_name} (ID: ${m.employee_id}, Role: ${m.role})`).join(', ') || 'NONE');
        }

    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
