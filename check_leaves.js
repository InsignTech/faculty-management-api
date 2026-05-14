const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'admin',
    password: 'mysqladmin',
    database: 'staffdesk',
});

async function test() {
    try {
        const [leaves] = await pool.execute('SELECT * FROM employee_leaves WHERE emp_id = 5');
        console.log("Leaves for Emp 5:", JSON.stringify(leaves, null, 2));
    } catch (e) {
        console.error(e);
    }
    process.exit(0);
}

test();
