const excelHelper = require('../utils/excelHelper');
const fs = require('fs');
const path = require('path');

async function test() {
    try {
        console.log('Generating Excel statement for period 1...');
        const workbook = await excelHelper.generateExcelStatement(1);
        const testOut = path.join(__dirname, 'test_output.xlsx');
        console.log('Writing test output to:', testOut);
        await workbook.xlsx.writeFile(testOut);
        console.log('Success! Excel file generated successfully.');
    } catch (e) {
        console.error('Failed to generate Excel:', e);
    } finally {
        process.exit();
    }
}
test();
