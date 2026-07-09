const pool = require('../config/db');
async function main() {
    try {
        console.log('Attempting to grant SYSTEM_USER privilege...');
        await pool.query("GRANT SYSTEM_USER ON *.* TO 'admin'@'localhost'");
        console.log('SYSTEM_USER privilege granted successfully!');
    } catch(err) {
        console.error('Failed to grant SYSTEM_USER privilege:', err.message);
    }
    process.exit(0);
}
main();
