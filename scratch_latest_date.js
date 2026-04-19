const pool = require('./config/db');

async function getLatest() {
    try {
        const [rows] = await pool.query("SELECT MAX(date) as latest_date FROM attendance");
        console.log("Latest date in attendance:", rows[0].latest_date);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        process.exit(0);
    }
}

getLatest();
