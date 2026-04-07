const pool = require('../config/db');

class HolidayModel {
    static async getAll(year) {
        const [rows] = await pool.execute('CALL sp_get_holidays(?)', [year || null]);
        return rows[0];
    }

    static async save(holidayId, holidayDate, description, isActive) {
        const [rows] = await pool.execute('CALL sp_save_holiday(?, ?, ?, ?)', [holidayId || 0, holidayDate, description, isActive]);
        return rows[0][0];
    }

    static async delete(holidayId) {
        const [rows] = await pool.execute('CALL sp_delete_holiday(?)', [holidayId]);
        return rows[0][0];
    }
}

class AttendanceSettingsModel {
    static async getAll() {
        const [rows] = await pool.execute('CALL sp_get_attendance_settings()');
        return rows[0];
    }

    static async updateSetting(key, value) {
        const [rows] = await pool.execute('CALL sp_update_attendance_setting(?, ?)', [key, value]);
        return rows[0][0];
    }
}

module.exports = { HolidayModel, AttendanceSettingsModel };
