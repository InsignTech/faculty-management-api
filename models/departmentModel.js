const pool = require('../config/db');

class DepartmentModel {
  static async create(departmentname) {
    const [rows] = await pool.execute(
      'CALL sp_create_department(?)',
      [departmentname]
    );
    return rows[0][0];
  }

  static async getAll() {
    const [rows] = await pool.execute('CALL sp_get_departments()');
    return rows[0];
  }

  static async getById(department_id) {
    const [rows] = await pool.execute(
      'CALL sp_get_department_by_id(?)',
      [department_id]
    );
    return rows[0][0];
  }

  static async update(department_id, departmentname) {
    const [rows] = await pool.execute(
      'CALL sp_update_department(?, ?)',
      [department_id, departmentname]
    );
    return rows[0][0];
  }

  static async delete(department_id) {
    await pool.execute('CALL sp_delete_department(?)', [department_id]);
    return true;
  }
}

module.exports = DepartmentModel;
