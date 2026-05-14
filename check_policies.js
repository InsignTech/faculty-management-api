const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'admin',
    password: 'mysqladmin',
    database: 'staffdesk',
});

async function test() {
    try {
        const [policies] = await pool.execute('SELECT * FROM leave_policy');
        console.log("Policies Details:", JSON.stringify(policies, null, 2));
    } catch (e) {
        console.error(e);
    }
    process.exit(0);
}

test();
