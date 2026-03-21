const pool = require('../config/db');

class PrivilegeModel {
    static async getByRoleId(roleId) {
        const [rows] = await pool.execute('CALL sp_get_role_privileges(?)', [roleId]);
        return rows[0];
    }

    static async save(roleId, settingsId, privilegeValue) {
        const [rows] = await pool.execute('CALL sp_save_role_privilege(?, ?, ?)', [
            roleId,
            settingsId,
            JSON.stringify(privilegeValue)
        ]);
        return rows[0][0];
    }
}

module.exports = PrivilegeModel;
