const ExcelJS = require('exceljs');
const path = require('path');

async function main() {
    try {
        const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.readFile(filePath);

        const sheet = workbook.getWorksheet('APRIL  REMU');
        sheet.eachRow((row, rNum) => {
            row.eachCell((cell, cNum) => {
                if (cell.formula || cell.formulaType || (cell.model && cell.model.formula)) {
                    console.log(`Row ${rNum} Col ${cNum} (${cell.address}):`, {
                        type: cell.type,
                        formula: cell.formula,
                        formulaType: cell.formulaType,
                        result: cell.result,
                        model: cell.model
                    });
                }
            });
        });
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
