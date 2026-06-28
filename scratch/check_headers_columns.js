const ExcelJS = require('exceljs');
const path = require('path');

async function main() {
    try {
        const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.readFile(filePath);

        const salarySheet = workbook.getWorksheet('APRIL SALARY');
        console.log('--- SALARY Row 4 headers ---');
        const row4 = salarySheet.getRow(4);
        for (let col = 1; col <= 25; col++) {
            const cell = row4.getCell(col);
            if (cell.value) {
                console.log(`Col ${col} (${cell.address}): "${cell.value}"`);
            }
        }

        const remuSheet = workbook.getWorksheet('APRIL  REMU');
        console.log('\n--- REMU Row 3 headers ---');
        const row3 = remuSheet.getRow(3);
        for (let col = 1; col <= 25; col++) {
            const cell = row3.getCell(col);
            if (cell.value) {
                console.log(`Col ${col} (${cell.address}): "${cell.value}"`);
            }
        }

    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
