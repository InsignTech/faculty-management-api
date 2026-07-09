const pool = require('../config/db');

async function test() {
    try {
        console.log("Creating table attendance_punches_detail...");
        await pool.query(`
            CREATE TABLE IF NOT EXISTS \`attendance_punches_detail\` (
                \`log_id\` INT NOT NULL AUTO_INCREMENT,
                \`employee_code\` VARCHAR(45) NULL,
                \`punch_time\` DATETIME NULL,
                \`created_on\` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
                \`processed_flag\` INT NULL DEFAULT 0,
                PRIMARY KEY (\`log_id\`),
                UNIQUE KEY \`idx_emp_punch\` (\`employee_code\`, \`punch_time\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
        `);
        console.log("Table attendance_punches_detail created successfully.");
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}
test();
