const pool = require('../config/db');

class HolidayModel {
    static async getAll(year = null) {
        const [rows] = await pool.execute('CALL sp_get_holidays(?)', [year]);
        return rows[0];
    }

    static async save(holidayData) {
        const { holiday_id, holiday_date, description, is_active } = holidayData;
        const [rows] = await pool.execute('CALL sp_save_holiday(?, ?, ?, ?)', [
            holiday_id || 0,
            holiday_date,
            description,
            is_active !== undefined ? is_active : 1
        ]);
        return rows[0][0];
    }

    static async delete(id) {
        const [rows] = await pool.execute('CALL sp_delete_holiday(?)', [id]);
        return rows[0][0];
    }

    static async getSettings() {
        const [rows] = await pool.execute('CALL sp_get_attendance_settings()');
        return rows[0];
    }

    static async updateSetting(key, value) {
        const [rows] = await pool.execute('CALL sp_update_attendance_setting(?, ?)', [key, value]);
        return rows[0][0];
    }
}

module.exports = HolidayModel;
