const pool = require('../config/db');

class DesignationModel {
  static async create(designation, created_by) {
    const [rows] = await pool.execute(
      'CALL sp_create_designation(?, ?)',
      [designation || '', created_by || 'admin']
    );
    return rows[0][0];
  }

  static async getAll() {
    const [rows] = await pool.execute('CALL sp_get_designations()');
    return rows[0];
  }

  static async getById(designation_id) {
    const [rows] = await pool.execute(
      'CALL sp_get_designation_by_id(?)',
      [designation_id]
    );
    return rows[0][0];
  }

  static async update(designation_id, designation) {
    const [rows] = await pool.execute(
      'CALL sp_update_designation(?, ?)',
      [designation_id, designation]
    );
    return rows[0][0];
  }

  static async delete(designation_id) {
    await pool.execute('CALL sp_delete_designation(?)', [designation_id]);
    return true;
  }
}

module.exports = DesignationModel;
