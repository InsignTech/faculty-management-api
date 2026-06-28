const XLSX = require('xlsx');
const path = require('path');

const filePath = path.join(__dirname, '..', '..', 'APRIL 2026 -1.xlsx');
console.log('Reading file:', filePath);
try {
  const workbook = XLSX.readFile(filePath);
  console.log('Sheet Names:', workbook.SheetNames);
  workbook.SheetNames.forEach(sheetName => {
    const sheet = workbook.Sheets[sheetName];
    const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
    console.log(`\n--- Sheet: ${sheetName} ---`);
    console.log('Row count:', data.length);
    console.log('First 35 rows:');
    data.slice(0, 35).forEach((row, i) => {
      console.log(`Row ${i + 1}:`, JSON.stringify(row));
    });
  });
} catch (err) {
  console.error('Error reading excel:', err);
}
