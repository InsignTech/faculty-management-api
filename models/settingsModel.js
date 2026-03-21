const pool = require('../config/db');

class SettingsModel {
    static async getSettingByKey(key) {
        const [rows] = await pool.execute('CALL sp_get_setting(?)', [key]);
        return rows[0][0];
    }
}

module.exports = SettingsModel;
