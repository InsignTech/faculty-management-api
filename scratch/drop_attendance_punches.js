const pool = require('../config/db');

async function test() {
    try {
        console.log("Dropping table attendance_punches...");
        await pool.query("DROP TABLE IF EXISTS attendance_punches");
        console.log("Table attendance_punches dropped successfully.");
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
