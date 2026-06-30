const ExcelJS = require('exceljs');
const path = require('path');

async function main() {
    try {
        const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.readFile(filePath);

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

        // Try writing it out
        const testOut = path.join(__dirname, 'test_output_stripped.xlsx');
        console.log('Writing test output...');
        await workbook.xlsx.writeFile(testOut);
        console.log('Success! Stripped workbook saved successfully.');
    } catch (e) {
        console.error('Failed:', e);
    } finally {
        process.exit();
    }
}
main();
