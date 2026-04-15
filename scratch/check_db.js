const mysql = require('mysql2/promise');
require('dotenv').config();

async function checkDb() {
    const pool = mysql.createPool({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME
    });

    try {
        const [tables] = await pool.query("SHOW TABLES LIKE 'settings'");
        console.log('Tables:', tables);
        
        if (tables.length > 0) {
            const [columns] = await pool.query("DESCRIBE settings");
            console.log('Columns:', columns);
            
            const [data] = await pool.query("SELECT * FROM settings");
            console.log('Data:', data);
        }

        const [procs] = await pool.query("SHOW PROCEDURE STATUS WHERE Db = ? AND Name = 'sp_get_setting'", [process.env.DB_NAME]);
        console.log('Procedures:', procs);
    } catch (err) {
        console.error(err);
    } finally {
        await pool.end();
    }
}

checkDb();
