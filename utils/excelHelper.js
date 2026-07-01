const ExcelJS = require('exceljs');
const path = require('path');
const pool = require('../config/db');

const MONTH_NAMES = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
];

async function generateExcelStatement(periodId, sortBy = 'id') {
    const [periods] = await pool.execute('SELECT * FROM payroll_period WHERE period_id = ?', [periodId]);
    if (periods.length === 0) throw new Error('Payroll period not found');
    const period = periods[0];
    const monthStr = MONTH_NAMES[period.month - 1];
    const yearStr = period.year.toString();

    const orderClause = sortBy === 'name' ? 'e.employee_name ASC' : 'sd.employee_id ASC';

    const [disbursements] = await pool.execute(`
        SELECT sd.*, 
               e.employee_name, 
               e.employee_code, 
               e.joining_date,
               r.role,
               d.departmentname AS department_name, 
               des.designation AS designation_name
        FROM salary_disbursement sd
        JOIN employee e ON sd.employee_id = e.employee_id
        LEFT JOIN app_role r ON e.role_id = r.role_id
        LEFT JOIN department d ON e.department_id = d.department_id
        LEFT JOIN designation des ON e.designation_id = des.designation_id
        WHERE sd.period_id = ?
        ORDER BY ${orderClause}
    `, [periodId]);

    const templatePath = path.join(__dirname, '..', 'APRIL 2026 -1.xlsx');
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.readFile(templatePath);

    // Strip shared formula properties from all cells to prevent ExcelJS build errors
    workbook.eachSheet((sheet) => {
        sheet.eachRow((row) => {
            row.eachCell((cell) => {
                if (cell.model) {
                    delete cell.model.sharedFormula;
                    delete cell.model.shareType;
                    delete cell.model.ref;
                    delete cell.model.si;
                }
            });
        });
    });

    const salarySheet = workbook.getWorksheet('APRIL SALARY');
    const remuSheet = workbook.getWorksheet('APRIL  REMU');

    if (!salarySheet || !remuSheet) {
        throw new Error('Template sheets not found');
    }

    salarySheet.name = `${monthStr} SALARY`;
    remuSheet.name = `${monthStr}  REMU`;

    salarySheet.getCell('B2').value = `SALARY STATEMENT FOR THE MONTH OF ${monthStr}  ${yearStr}`;
    remuSheet.getCell('B2').value = `REMUNERATION FOR THE MONTH OF ${monthStr} ${yearStr}`;

    const templateSalaryNames = new Set();
    for (let r = 5; r <= 14; r++) {
        const val = salarySheet.getCell(r, 3).value; // Name is in Col 3 (C)
        if (val && typeof val === 'string' && val.trim() && val !== 'Prepared By: ') {
            templateSalaryNames.add(val.trim().toLowerCase().replace(/[^a-z0-9]/g, ''));
        }
    }

    const templateRemuNames = new Set();
    for (let r = 4; r <= 18; r++) {
        const val = remuSheet.getCell(r, 3).value; // Name is in Col 3 (C)
        if (val && typeof val === 'string' && val.trim()) {
            templateRemuNames.add(val.trim().toLowerCase().replace(/[^a-z0-9]/g, ''));
        }
    }
    for (let r = 37; r <= 46; r++) {
        const val = remuSheet.getCell(r, 3).value;
        if (val && typeof val === 'string' && val.trim()) {
            templateRemuNames.add(val.trim().toLowerCase().replace(/[^a-z0-9]/g, ''));
        }
    }

    const salaryDisbs = [];
    const remuDisbs = [];

    disbursements.forEach(d => {
        const norm = d.employee_name.trim().toLowerCase().replace(/[^a-z0-9]/g, '');
        if (templateRemuNames.has(norm)) {
            remuDisbs.push(d);
        } else if (templateSalaryNames.has(norm)) {
            salaryDisbs.push(d);
        } else {
            const role = (d.role || '').toUpperCase();
            const designation = (d.designation_name || '').toUpperCase();
            if (role === 'GUEST / TEMP' || role === 'GENERAL' || designation === 'SECURITY') {
                remuDisbs.push(d);
            } else {
                salaryDisbs.push(d);
            }
        }
    });

    const copyCell = (srcCell, destCell) => {
        destCell.style = srcCell.style;
        destCell.numFmt = srcCell.numFmt;
    };

    // ================= POPULATE SALARY SHEET =================
    const salaryRefRow = salarySheet.getRow(5);
    const salaryCount = salaryDisbs.length;

    // Clear template employee rows
    for (let r = 5; r <= 14; r++) {
        salarySheet.getRow(r).values = [];
    }

    if (salaryCount > 10) {
        salarySheet.insertRows(15, Array(salaryCount - 10).fill([]));
    } else if (salaryCount < 10 && salaryCount > 0) {
        salarySheet.spliceRows(5 + salaryCount, 10 - salaryCount);
    }

    salaryDisbs.forEach((d, idx) => {
        const rIdx = 5 + idx;
        const row = salarySheet.getRow(rIdx);
        
        // Copy style starting from Col 2 (B) to Col 24 (X)
        for (let col = 2; col <= 24; col++) {
            copyCell(salaryRefRow.getCell(col), row.getCell(col));
        }

        const dec = typeof d.deductions_json === 'string' ? JSON.parse(d.deductions_json) : (d.deductions_json || {});
        const epfAmt = parseFloat(dec.EPF || 0);
        const epfBase = epfAmt > 0 ? Math.min(15000, parseFloat(d.basic_pay) * (1 - (parseFloat(d.lop_days) / 30))) : 0;
        const esiAmt = parseFloat(dec.ESI || 0);
        const esiBase = esiAmt > 0 ? parseFloat(d.payable_amount) : 0;
        const tds = parseFloat(dec.TDS || 0);
        const pt = parseFloat(dec.ProfessionTax || 0);
        const loan = parseFloat(dec.LoanEMI || 0);
        const busFee = parseFloat(dec.BusFee || 0);

        row.getCell(2).value = idx + 1; // Sl No in B
        row.getCell(3).value = d.employee_name; // Name in C
        let joinDateStr = '';
        if (d.joining_date) {
            const parts = d.joining_date.split('-');
            if (parts.length === 3) joinDateStr = `${parts[2]}.${parts[1]}.${parts[0]}`;
        }
        row.getCell(4).value = joinDateStr; // Dt of Joining in D
        row.getCell(5).value = d.department_name || ''; // Department in E
        row.getCell(6).value = parseFloat(d.basic_pay); // Basic Pay in F
        row.getCell(7).value = parseFloat(d.hra); // HRA in G
        row.getCell(8).value = parseFloat(d.educational_allowance); // Edu in H
        row.getCell(9).value = parseFloat(d.special_allowance); // Special in I
        row.getCell(10).value = parseFloat(d.naac_allowance); // NAAC in J
        // Gross in K
        row.getCell(11).value = { formula: `ROUND(SUM(F${rIdx}:J${rIdx}),0)`, result: parseFloat(d.gross_salary) };
        row.getCell(12).value = parseFloat(d.lop_days) || null; // LOP in L
        // Pay in M
        row.getCell(13).value = { formula: `ROUND(K${rIdx}*(30-IF(ISBLANK(L${rIdx}),0,L${rIdx}))/30,0)`, result: parseFloat(d.payable_amount) };
        row.getCell(14).value = epfBase || null; // EPF Base in N
        row.getCell(15).value = epfAmt || 0; // EPF 12% in O
        row.getCell(16).value = esiBase || null; // ESI Base in P
        row.getCell(17).value = esiAmt || 0; // ESI .75% in Q
        row.getCell(18).value = tds || 0; // TDS in R
        row.getCell(19).value = pt || 0; // PT in S
        row.getCell(20).value = loan || 0; // Loan in T
        row.getCell(21).value = busFee || 0; // Bus Fee in U
        // Total Ded in V
        row.getCell(22).value = { formula: `SUM(O${rIdx},Q${rIdx}:U${rIdx})`, result: parseFloat(d.total_deduction) };
        // Net in W
        row.getCell(23).value = { formula: `M${rIdx}-V${rIdx}`, result: parseFloat(d.net_salary) };
        row.getCell(24).value = d.remarks || ''; // Remarks in X
    });

    const salaryTotalsRowIdx = 5 + salaryCount;
    const sTotals = salarySheet.getRow(salaryTotalsRowIdx);
    sTotals.getCell(6).value = { formula: `SUM(F5:F${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(7).value = { formula: `SUM(G5:G${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(8).value = { formula: `SUM(H5:H${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(9).value = { formula: `SUM(I5:I${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(10).value = { formula: `SUM(J5:J${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(11).value = { formula: `SUM(K5:K${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(12).value = { formula: `SUM(L5:L${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(13).value = { formula: `SUM(M5:M${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(15).value = { formula: `SUM(O5:O${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(17).value = { formula: `SUM(Q5:Q${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(18).value = { formula: `SUM(R5:R${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(19).value = { formula: `SUM(S5:S${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(20).value = { formula: `SUM(T5:T${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(21).value = { formula: `SUM(U5:U${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(22).value = { formula: `SUM(V5:V${salaryTotalsRowIdx - 1})` };
    sTotals.getCell(23).value = { formula: `SUM(W5:W${salaryTotalsRowIdx - 1})` };

    const maxSalaryRow = salaryTotalsRowIdx + 15;
    salarySheet.eachRow((row, rNum) => {
        if (rNum > maxSalaryRow) {
            row.eachCell(cell => {
                cell.value = null;
            });
        }
    });

    // ================= POPULATE REMU SHEET =================
    const remuRefRow = remuSheet.getRow(4);
    const remuCount = remuDisbs.length;

    for (let r = 4; r <= 35; r++) {
        remuSheet.getRow(r).values = [];
    }
    for (let r = 37; r <= 100; r++) {
        remuSheet.getRow(r).values = [];
    }

    if (remuCount > 15) {
        remuSheet.insertRows(19, Array(remuCount - 15).fill([]));
    } else if (remuCount < 15 && remuCount > 0) {
        remuSheet.spliceRows(4 + remuCount, 15 - remuCount);
    }

    remuDisbs.forEach((d, idx) => {
        const rIdx = 4 + idx;
        const row = remuSheet.getRow(rIdx);

        for (let col = 1; col <= 22; col++) {
            copyCell(remuRefRow.getCell(col), row.getCell(col));
        }

        const dec = typeof d.deductions_json === 'string' ? JSON.parse(d.deductions_json) : (d.deductions_json || {});
        const epfAmt = parseFloat(dec.EPF || 0);
        const esiAmt = parseFloat(dec.ESI || 0);
        const pt = parseFloat(dec.ProfessionTax || 0);
        const busFee = parseFloat(dec.BusFee || 0);

        row.getCell(2).value = idx + 1;
        row.getCell(3).value = d.employee_name;
        row.getCell(4).value = d.designation_name || d.department_name || '';
        let joinDateStr = '';
        if (d.joining_date) {
            const parts = d.joining_date.split('-');
            if (parts.length === 3) joinDateStr = `${parts[2]}.${parts[1]}.${parts[0]}`;
        }
        row.getCell(5).value = joinDateStr;
        row.getCell(6).value = parseFloat(d.basic_pay);
        row.getCell(7).value = parseFloat(d.hra) || null;
        row.getCell(8).value = parseFloat(d.educational_allowance) || null;
        row.getCell(9).value = parseFloat(d.special_allowance) || 0;
        row.getCell(10).value = parseFloat(d.naac_allowance) || 0;
        row.getCell(11).value = { formula: `ROUND(SUM(F${rIdx}:J${rIdx}),0)`, result: parseFloat(d.gross_salary) };
        row.getCell(12).value = parseFloat(d.lop_days) || null;
        row.getCell(13).value = { formula: `ROUND(K${rIdx}*(30-IF(ISBLANK(L${rIdx}),0,L${rIdx}))/30,0)`, result: parseFloat(d.payable_amount) };
        row.getCell(14).value = epfAmt || null;
        row.getCell(15).value = esiAmt || null;
        row.getCell(16).value = pt || null;
        row.getCell(17).value = busFee || null;
        row.getCell(18).value = { formula: `SUM(N${rIdx}:Q${rIdx})`, result: parseFloat(d.total_deduction) };
        row.getCell(19).value = { formula: `M${rIdx}-R${rIdx}`, result: parseFloat(d.net_salary) };
        row.getCell(20).value = d.remarks || '';
    });

    const remuTotalsRowIdx = 4 + remuCount;
    const rTotals = remuSheet.getRow(remuTotalsRowIdx);
    
    rTotals.getCell(10).value = { formula: `SUM(J4:J${remuTotalsRowIdx - 1})` };
    rTotals.getCell(11).value = { formula: `SUM(K4:K${remuTotalsRowIdx - 1})` };
    rTotals.getCell(13).value = { formula: `SUM(M4:M${remuTotalsRowIdx - 1})` };
    rTotals.getCell(14).value = { formula: `SUM(N4:N${remuTotalsRowIdx - 1})` };
    rTotals.getCell(15).value = { formula: `SUM(O4:O${remuTotalsRowIdx - 1})` };
    rTotals.getCell(16).value = { formula: `SUM(P4:P${remuTotalsRowIdx - 1})` };
    rTotals.getCell(17).value = { formula: `SUM(Q4:Q${remuTotalsRowIdx - 1})` };
    rTotals.getCell(18).value = { formula: `SUM(R4:R${remuTotalsRowIdx - 1})` };
    rTotals.getCell(19).value = { formula: `SUM(S4:S${remuTotalsRowIdx - 1})` };

    const grandTotalsRowIdx = remuTotalsRowIdx + 2;
    const grandTotalsRow = remuSheet.getRow(grandTotalsRowIdx);
    grandTotalsRow.getCell(18).value = { formula: `S${remuTotalsRowIdx}+R${remuTotalsRowIdx}` };
    
    const salarySheetRefName = `${monthStr} SALARY`;
    grandTotalsRow.getCell(22).value = { formula: `'${salarySheetRefName}'!W${salaryTotalsRowIdx}+S${remuTotalsRowIdx}` }; // Net salary in salary sheet is in W

    const maxRemuRow = grandTotalsRowIdx + 5;
    remuSheet.eachRow((row, rNum) => {
        if (rNum > maxRemuRow) {
            row.eachCell(cell => {
                cell.value = null;
            });
        }
    });

    return workbook;
}

module.exports = {
    generateExcelStatement
};
