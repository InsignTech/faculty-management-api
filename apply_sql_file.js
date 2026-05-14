const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

async function applySqlFile() {
    const fileName = process.argv[2];
    if (!fileName) {
        console.error('Please provide a filename in the db directory.');
        process.exit(1);
    }

    // NOTE: Temporarily using root to bypass SYSTEM_USER privilege issues when dropping/creating procedures
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: 'root',
        password: 'mysqladmin',
        database: process.env.DB_NAME,
        multipleStatements: true
    });

    try {
        console.log(`Reading SQL file: ${fileName}...`);
        const sqlPath = path.join(__dirname, 'db', fileName);
        const sql = fs.readFileSync(sqlPath, 'utf8');

        // Clean up the SQL by removing DELIMITER lines
        const cleanSql = sql.replace(/^DELIMITER.*$/gm, '');
        
        // Split by // but only if // is present, otherwise split by ;
        let commands = [];
        if (cleanSql.includes('//')) {
            commands = cleanSql.split('//').filter(cmd => cmd.trim().length > 0);
        } else {
            commands = cleanSql.split(';').filter(cmd => cmd.trim().length > 0);
        }

        console.log(`Applying ${commands.length} commands...`);
        for (let cmd of commands) {
            cmd = cmd.trim();
            if (cmd) {
                await connection.query(cmd);
            }
        }
        console.log(`Successfully applied ${fileName}!`);
    } catch (error) {
        console.error('Error applying SQL:', error);
    } finally {
        await connection.end();
        process.exit();
    }
}

applySqlFile();
