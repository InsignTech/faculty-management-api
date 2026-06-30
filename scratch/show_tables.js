const pool = require('../config/db');

async function check() {
    try {
        const [rows] = await pool.execute('SHOW TABLES');
        console.log("Existing Tables:");
        console.log(rows.map(r => Object.values(r)[0]));
    } catch (e) {
        console.error("Error:", e);
    }
    process.exit(0);
}
check();
