
require('dotenv').config({ path: 'd:/PROJECT/2025/New folder/backend_api/.env' });
const pool = require('./config/db');

async function debug() {
    try {
        const [policies] = await pool.execute('SELECT * FROM leave_policy');
        console.log('--- SYSTEM POLICIES ---');
        console.log(JSON.stringify(policies, null, 2));

        const [settings] = await pool.execute('SELECT * FROM settings');
        console.log('--- SETTINGS ---');
        console.log(settings);

        const [empCount] = await pool.execute('SELECT COUNT(*) as count FROM employee WHERE active = 1');
        console.log('--- ACTIVE EMPLOYEES ---');
        console.log(empCount[0].count);

        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

debug();
