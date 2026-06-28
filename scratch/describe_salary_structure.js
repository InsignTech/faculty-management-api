const pool = require('../config/db');

async function main() {
    try {
        const [cols] = await pool.query('DESCRIBE salary_structure');
        console.log(cols);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
