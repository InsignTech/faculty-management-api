const pool = require('./config/db');

async function showTriggers() {
    try {
        const [rows] = await pool.query("SHOW TRIGGERS");
        console.log("TRIGGERS:", rows);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        process.exit(0);
    }
}

showTriggers();
