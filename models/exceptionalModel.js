const pool = require('../config/db');

class ExceptionalModel {
    /**
     * Get all global exceptional days for a year
     */
    static async getAll(year) {
        const [rows] = await pool.execute(
            'CALL sp_get_exceptional_days(?)',
            [year || null]
        );
        return rows[0];
    }

    /**
     * Save/Update a global exceptional day
     */
    static async save(data) {
        const { exceptional_id, holiday_date, description, is_active } = data;
        const [rows] = await pool.execute(
            'CALL sp_save_exceptional_day(?, ?, ?, ?)',
            [exceptional_id || 0, holiday_date, description, is_active ?? 1]
        );
        return rows[0][0];
    }

    /**
     * Delete a global exceptional day
     */
    static async delete(id) {
        const [rows] = await pool.execute(
            'CALL sp_delete_exceptional_day(?)',
            [id]
        );
        return rows[0][0];
    }
}

module.exports = ExceptionalModel;
