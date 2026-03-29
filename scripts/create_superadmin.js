/**
 * Run this script ONCE to create the superadmin user.
 * Usage: node scripts/create_superadmin.js
 * 
 * Default credentials:
 *   Email:    admin@staffdesk.com
 *   Password: Admin@123
 */

const bcrypt = require('bcryptjs');
const pool = require('../config/db');

async function createSuperAdmin() {
    const email = 'admin@staffdesk.com';
    const password = 'Admin@123';
    const displayName = 'Super Admin';
    const roleId = 1; // Change if your admin role_id is different

    console.log('Creating superadmin user...');

    // Check if already exists
    const [existing] = await pool.execute(
        'SELECT user_accounts_id FROM user_accounts WHERE email = ?',
        [email]
    );

    if (existing.length > 0) {
        console.log(`⚠️  User with email "${email}" already exists (ID: ${existing[0].user_accounts_id})`);
        console.log('Run the update block below to reset the password instead.');
        
        // Update password for existing user
        const salt = await bcrypt.genSalt(10);
        const hash = await bcrypt.hash(password, salt);
        await pool.execute(
            'UPDATE user_accounts SET user_password = ?, active = 1 WHERE email = ?',
            [hash, email]
        );
        console.log(`✅ Password reset to "${password}" for existing user.`);
        await pool.end();
        return;
    }

    // Hash the password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Insert superadmin
    const [result] = await pool.execute(
        `INSERT INTO user_accounts 
         (user_display_name, user_password, employee_id, email, active, role_id, created_on, created_by) 
         VALUES (?, ?, NULL, ?, 1, ?, NOW(), 'system')`,
        [displayName, hashedPassword, email, roleId]
    );

    console.log(`\n✅ Superadmin created successfully!`);
    console.log(`   ID:       ${result.insertId}`);
    console.log(`   Email:    ${email}`);
    console.log(`   Password: ${password}`);
    console.log(`\n⚠️  Change this password after first login at /reset-password\n`);

    await pool.end();
}

createSuperAdmin().catch(err => {
    console.error('❌ Failed to create superadmin:', err.message);
    process.exit(1);
});
