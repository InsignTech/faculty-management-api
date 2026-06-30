const ExcelJS = require('exceljs');
const path = require('path');

async function main() {
    try {
        const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.readFile(filePath);

        const salarySheet = workbook.getWorksheet('APRIL SALARY');
        console.log('--- SALARY Row 1 & 2 cells ---');
        for (let col = 1; col <= 25; col++) {
            const c1 = salarySheet.getRow(1).getCell(col);
            const c2 = salarySheet.getRow(2).getCell(col);
            if (c1.value) console.log(`Row 1 Col ${col} (${c1.address}):`, c1.value);
            if (c2.value) console.log(`Row 2 Col ${col} (${c2.address}):`, c2.value);
        }

        const remuSheet = workbook.getWorksheet('APRIL  REMU');
        console.log('\n--- REMU Row 1 & 2 cells ---');
        for (let col = 1; col <= 25; col++) {
            const c1 = remuSheet.getRow(1).getCell(col);
            const c2 = remuSheet.getRow(2).getCell(col);
            if (c1.value) console.log(`Row 1 Col ${col} (${c1.address}):`, c1.value);
            if (c2.value) console.log(`Row 2 Col ${col} (${c2.address}):`, c2.value);
        }

    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
