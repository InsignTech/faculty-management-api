// This script can be executed via cron: node jobs/exampleJob.js
const pool = require('../config/db');

const runJob = async () => {
    try {
        console.log('Running background job...');
        // Example: CALL sp_some_reporting_procedure()
        // const [results] = await pool.execute('CALL sp_get_faculty_profile(1)');
        // console.log('Job results:', results[0]);
        console.log('Background job completed successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Job failed:', err);
        process.exit(1);
    }
};

runJob();
