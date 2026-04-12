const pool = require('../config/db');

class UserModel {
    static async signup(username, email, hashedPassword, roleId, employeeId = null) {
        const [rows] = await pool.execute(
            `INSERT INTO user_accounts 
            (user_display_name, email, user_password, role_id, employee_id, active, created_on, created_by) 
            VALUES (?, ?, ?, ?, ?, 1, NOW(), 'system')`,
            [username, email, hashedPassword, roleId, employeeId]
        );
        return { user_accounts_id: rows.insertId };
    }

    static async findByEmail(email) {
        const [rows] = await pool.execute('CALL sp_get_user_auth_details(?)', [email]);
        return rows[0][0];
    }

    static async findById(id) {
        const [rows] = await pool.execute('SELECT * FROM user_accounts WHERE user_accounts_id = ?', [id]);
        return rows[0];
    }

    static async updateOTP(email, otp) {
        const [rows] = await pool.execute('CALL sp_update_user_otp(?, ?)', [email, otp]);
        return rows[0][0];
    }

    static async resetPasswordWithOld(userId, newHashedPassword) {
        const [rows] = await pool.execute('CALL sp_reset_password_with_old(?, ?)', [userId, newHashedPassword]);
        return rows[0][0];
    }

    static async resetPasswordWithOTP(email, otp, newHashedPassword) {
        const [rows] = await pool.execute('CALL sp_reset_password_with_otp(?, ?, ?)', [email, otp, newHashedPassword]);
        return rows[0][0];
    }

    static async updateEmailByEmployeeId(employeeId, newEmail) {
        const [result] = await pool.execute(
            'UPDATE user_accounts SET email = ? WHERE employee_id = ?',
            [newEmail, employeeId]
        );
        return result;
    }
}

module.exports = UserModel;
