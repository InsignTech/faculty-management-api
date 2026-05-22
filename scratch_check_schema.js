const pool = require('./config/db');

async function checkSchema() {
    try {
        const [attColumns] = await pool.query("DESCRIBE attendance_daily");
        console.log("attendance_daily columns:", attColumns);
        
        const [leavesColumns] = await pool.query("DESCRIBE leave_requests");
        console.log("leave_requests columns:", leavesColumns);
        
        const [types] = await pool.query("SELECT DISTINCT leave_type FROM employee_leaves LIMIT 20");
        console.log("employee_leaves unique types:", types);
        const [reqTypes] = await pool.query("SELECT DISTINCT leave_type FROM leave_requests LIMIT 20");
        console.log("leave_requests unique types:", reqTypes);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit(0);
    }
}

checkSchema();
