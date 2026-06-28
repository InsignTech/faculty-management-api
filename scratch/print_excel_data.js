const XLSX = require('xlsx');
const path = require('path');

try {
    const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
    const workbook = XLSX.readFile(filePath);

    workbook.SheetNames.forEach(sheetName => {
        const sheet = workbook.Sheets[sheetName];
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
        console.log(`\n--- Sheet: ${sheetName} ---`);
        let count = 0;
        data.forEach((row, i) => {
            // Check if row has any non-null elements
            if (row && row.some(cell => cell !== null && cell !== '')) {
                count++;
                console.log(`Row ${i + 1}:`, JSON.stringify(row));
            }
        });
        console.log(`Total active rows: ${count}`);
    });
} catch (e) {
    console.error(e);
}
