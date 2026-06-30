const ExcelJS = require('exceljs');
const path = require('path');

async function main() {
    try {
        const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.readFile(filePath);

        workbook.eachSheet((sheet, id) => {
            console.log(`\n================ Sheet: ${sheet.name} ================`);
            console.log(`Row count: ${sheet.rowCount}`);
            
            // Print first 25 rows with formula and type info
            for (let r = 1; r <= 25; r++) {
                const row = sheet.getRow(r);
                const values = [];
                for (let c = 1; c <= 25; c++) {
                    const cell = row.getCell(c);
                    if (cell.value !== null && cell.value !== undefined) {
                        let display = cell.value;
                        if (cell.value && typeof cell.value === 'object' && cell.value.formula) {
                            display = `{Formula: ${cell.value.formula}, Result: ${cell.value.result}}`;
                        }
                        values.push(`Col ${c}: ${JSON.stringify(display)}`);
                    }
                }
                if (values.length > 0) {
                    console.log(`Row ${r}:`, values.join(' | '));
                }
            }
        });
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
