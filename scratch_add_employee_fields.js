const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'admin',
    password: 'mysqladmin',
    database: 'staffdesk',
});

async function migrate() {
    try {
        console.log("Checking employee table columns...");
        
        // Fetch existing columns
        const [columns] = await pool.query("SHOW COLUMNS FROM employee");
        const columnNames = columns.map(c => c.Field.toLowerCase());
        
        const newColumns = [
            { name: 'educational_qualification', type: 'VARCHAR(255) DEFAULT NULL' },
            { name: 'additional_qualification', type: 'VARCHAR(255) DEFAULT NULL' },
            { name: 'present_address', type: 'TEXT DEFAULT NULL' },
            { name: 'permanent_address', type: 'TEXT DEFAULT NULL' },
            { name: 'contact_number', type: 'VARCHAR(20) DEFAULT NULL' },
            { name: 'alternative_contact_number', type: 'VARCHAR(20) DEFAULT NULL' }
        ];
        
        for (const col of newColumns) {
            if (!columnNames.includes(col.name.toLowerCase())) {
                console.log(`Adding column: ${col.name}`);
                await pool.query(`ALTER TABLE employee ADD COLUMN ${col.name} ${col.type}`);
                console.log(`Column ${col.name} added successfully!`);
            } else {
                console.log(`Column ${col.name} already exists.`);
            }
        }
        
        console.log("Database migration complete!");
    } catch (e) {
        console.error("Migration error:", e);
    } finally {
        await pool.end();
        process.exit(0);
    }
}

migrate();
