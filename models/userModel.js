const pool = require('../config/db');

class UserModel {
    static async signup(username, email, hashedPassword, roleId, employeeId = null) {
        // sp_signup needs to be checked or created if not in dump
        // For now, using direct query or basic SP call if exists
        const [rows] = await pool.execute(
            'INSERT INTO user_accounts (user_display_name, email, user_password, role_id, employee_id, active) VALUES (?, ?, ?, ?, ?, 1)',
            [username, email, hashedPassword, roleId, employeeId]
        );
        return { user_accounts_id: rows.insertId };
    }

    static async findByEmail(email) {
        const [rows] = await pool.execute(
            'SELECT * FROM user_accounts WHERE email = ?',
            [email]
        );
        return rows[0];
    }

    static async findById(id) {
        const [rows] = await pool.execute(
            'SELECT * FROM user_accounts WHERE user_accounts_id = ?',
            [id]
        );
        return rows[0];
    }
}

module.exports = UserModel;
