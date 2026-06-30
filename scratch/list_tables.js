const pool = require('../config/db');

async function main() {
    try {
        const [tables] = await pool.query('SHOW TABLES');
        console.log('Tables:');
        console.log(tables);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
main();
