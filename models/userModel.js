const pool = require('../config/db');

class UserModel {
    static async signup(username, email, hashedPassword, role) {
        const [rows] = await pool.execute(
            'CALL sp_signup(?, ?, ?, ?)',
            [username, email, hashedPassword, role]
        );
        return rows[0][0]; // mysql2 returns nested arrays for stored procedures
    }

    static async findByEmail(email) {
        const [rows] = await pool.execute(
            'CALL sp_login(?)',
            [email]
        );
        return rows[0][0];
    }

    static async findById(id) {
        const [rows] = await pool.execute(
            'CALL sp_get_faculty_profile(?)',
            [id]
        );
        return rows[0][0];
    }
}

module.exports = UserModel;
