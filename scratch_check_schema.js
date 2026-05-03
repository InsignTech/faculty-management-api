const pool = require('./config/db');

async function checkSchema() {
    try {
        const [rows] = await pool.query("SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'staffdesk' AND TABLE_NAME = 'leave_requests' AND COLUMN_NAME = 'total_days'");
        console.log(JSON.stringify(rows, null, 2));
    } catch (err) {
        console.error(err);
    } finally {
        process.exit(0);
    }
}

checkSchema();
