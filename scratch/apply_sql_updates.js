const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const pool = require('../config/db');
const fs = require('fs');

async function runSqlFile(filePath) {
    const sql = fs.readFileSync(filePath, 'utf8');
    const statements = sql.split('//').filter(s => s.trim() !== '' && !s.includes('DELIMITER'));
    
    for (let statement of statements) {
        // Remove 'DELIMITER //' and similar
        statement = statement.replace(/DELIMITER \/\//g, '').replace(/DELIMITER ;/g, '').trim();
        if (!statement) continue;
        
        console.log(`Executing statement from ${path.basename(filePath)}...`);
        try {
            await pool.query(statement);
        } catch (err) {
            console.error(`Error executing statement: ${err.message}`);
        }
    }
}

async function main() {
    try {
        console.log('Starting SQL updates...');
        
        // 1. Update sp_approve_leave
        await runSqlFile(path.join(__dirname, '../db/update_sp_approve_leave.sql'));
        
        // 2. Create sp_cancel_leave
        await runSqlFile(path.join(__dirname, '../db/sp_cancel_leave.sql'));
        
        console.log('SQL updates completed.');
        process.exit(0);
    } catch (err) {
        console.error('Fatal error:', err);
        process.exit(1);
    }
}

main();
