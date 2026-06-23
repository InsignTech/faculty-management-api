const pool = require('../config/db');

async function check() {
    try {
        const [attColumns] = await pool.execute("SHOW COLUMNS FROM attendance_daily");
        console.log("attendance_daily columns:", attColumns.map(c => `${c.Field} (${c.Type})`));

        const [empColumns] = await pool.execute("SHOW COLUMNS FROM employee");
        console.log("employee columns:", empColumns.map(c => `${c.Field} (${c.Type})`));
    } catch (e) {
        console.error("Error:", e);
    }
    process.exit(0);
}
check();
