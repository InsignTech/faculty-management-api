const pool = require('../config/db');
async function main() {
    const [userRows] = await pool.query('SELECT CURRENT_USER(), USER()');
    console.log('Current user:', userRows);
    try {
        const [grantRows] = await pool.query('SHOW GRANTS');
        console.log('Grants:', grantRows);
    } catch(err) {
        console.error('Failed to show grants:', err);
    }
    process.exit(0);
}
main();
