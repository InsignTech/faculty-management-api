const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'admin',
    password: 'mysqladmin',
    database: 'staffdesk',
});

async function test() {
    try {
        const [rows] = await pool.execute("SHOW CREATE PROCEDURE sp_process_attendance");
        const def = rows[0]['Create Procedure'];
        const lines = def.split('\n');
        // Let's get the first 300 lines
        console.log("SP Definition (Part 1):\n", lines.slice(0, 300).join('\n'));
    } catch (e) {
        console.error(e.message);
    }
    process.exit(0);
}

test();
