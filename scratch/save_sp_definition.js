require('dotenv').config({ path: 'd:/PROJECT/2025/New folder/backend_api/.env' });
const pool = require('../config/db');
const fs = require('fs');

async function getSP() {
    try {
        const [rows] = await pool.query("SHOW CREATE PROCEDURE sp_approve_leave");
        const definition = rows[0]['Create Procedure'];
        fs.writeFileSync('d:/PROJECT/2025/New folder/backend_api/scratch/sp_approve_leave_definition.sql', definition);
        console.log('Definition saved to scratch/sp_approve_leave_definition.sql');
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}

getSP();
