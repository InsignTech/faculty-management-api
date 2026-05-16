const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'admin',
    password: 'mysqladmin',
    database: 'staffdesk',
});

async function test() {
    try {
        const [rows] = await pool.execute("SHOW CREATE PROCEDURE sp_update_employee");
        console.log("SP Definition:", rows[0]['Create Procedure']);
    } catch (e) {
        console.error("Error fetching sp_update_employee:", e.message);
    }
    process.exit(0);
}

test();
