const pool = require('../config/db');

class RoleModel {
    static async getAll() {
        const [rows] = await pool.execute('CALL sp_get_roles()');
        return rows[0];
    }

    static async create(roleName) {
        const [rows] = await pool.execute('CALL sp_create_role(?)', [roleName]);
        return rows[0][0];
    }
}

module.exports = RoleModel;
