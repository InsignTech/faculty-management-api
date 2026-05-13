const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const pool = require('../config/db');
async function main() {
    try {
        const [rows] = await pool.query('SELECT * FROM leave_policy');
        console.table(rows);
        const [empCount] = await pool.query('SELECT COUNT(*) as count FROM employee WHERE active = 1');
        console.log('Active Employees:', empCount[0].count);
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}
main();
