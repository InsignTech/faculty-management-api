const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function applySql() {
    const pool = mysql.createPool({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME,
        multipleStatements: true
    });

    try {
        console.log('Reading SQL file...');
        const sqlPath = path.join(__dirname, 'db', 'attendance_management.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');

        console.log('Applying SQL changes to database...');
        // We need to handle DELIMITER manually or just split the file if it's too complex.
        // But since I have multiple statements and custom delimiters, 
        // I will split by '//' and ';' roughly or just use a simpler approach.
        
        // Actually, mysql2 supports multipleStatements but DELIMITER is a CLI-only command.
        // I'll trim the DELIMITER lines and use '//' as the delimiter for splitting.
        
        const cleanSql = sql.replace(/DELIMITER \/\/|DELIMITER ;/g, '');
        const commands = cleanSql.split('//').filter(cmd => cmd.trim().length > 0);

        for (const cmd of commands) {
            // Further split by ';' if not inside a BEGIN/END block? 
            // This is tricky. Let's just try running the procedures as they are.
            await pool.query(cmd);
        }

        console.log('Successfully updated stored procedures!');
    } catch (error) {
        console.error('Error applying SQL:', error);
    } finally {
        await pool.end();
    }
}

applySql();
