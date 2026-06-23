const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const mysql = require('mysql2/promise');
const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: 'mysqladmin',
    database: 'staffdesk',
    multipleStatements: true
});
const fs = require('fs');

async function runSqlFile(filePath) {
    const sql = fs.readFileSync(filePath, 'utf8');
    const statements = sql.split('//').filter(s => s.trim() !== '');
    
    for (let statement of statements) {
        statement = statement.trim();
        if (!statement) continue;
        
        console.log(`Executing statement from ${path.basename(filePath)}...`);
        try {
            await pool.query(statement);
            console.log('Success!');
        } catch (err) {
            console.error(`Error executing statement: ${err.message}`);
        }
    }
}

async function main() {
    try {
        console.log('Starting payroll SP update...');
        await runSqlFile(path.join(__dirname, '../db/payroll_sps.sql'));
        console.log('SP update completed.');
        process.exit(0);
    } catch (err) {
        console.error('Fatal error:', err);
        process.exit(1);
    }
}

main();
