const ExcelJS = require('exceljs');
const path = require('path');

async function main() {
    try {
        const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.readFile(filePath);

        const sheet = workbook.getWorksheet('APRIL  REMU');
        const cell = sheet.getCell('W53');
        console.log('--- Cell W53 Properties ---');
        console.log('Type:', cell.type);
        console.log('Value:', cell.value);
        console.log('Formula:', cell.formula);
        console.log('Formula Type:', cell.formulaType);
        console.log('Cell Model:', JSON.stringify(cell.model, null, 2));

        // Try clearing it
        cell.value = null;
        cell.formula = undefined;
        if (cell.model) {
            cell.model.formula = undefined;
            cell.model.sharedFormula = undefined;
        }
        console.log('\nAfter clearing:');
        console.log('Cell Model:', JSON.stringify(cell.model, null, 2));

    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
