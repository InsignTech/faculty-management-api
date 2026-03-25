const pool = require('../config/db');

class EmployeeModel {
  static async create(data) {
    const [rows] = await pool.execute(
      'CALL sp_create_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        data.organization_id || 1,
        data.employee_code || '',
        data.employee_name || '',
        data.employee_role || 0,
        data.designation_id || 0,
        data.employee_type || '',
        data.reporting_manager_id || null,
        data.joining_date || null,
        data.active !== undefined ? data.active : 1,
        data.created_by || 'admin',
        data.department_id || 0
      ]
    );
    return rows[0][0];
  }

  static async getAll() {
    const [rows] = await pool.execute('CALL sp_get_employees()');
    return rows[0];
  }

  static async getFiltered(searchTerm = '', roleId = 0) {
    const [rows] = await pool.execute('CALL sp_get_employees_filtered(?, ?)', [
      searchTerm || '',
      roleId || 0
    ]);
    return rows[0];
  }

  static async getPotentialManagers(searchTerm = '', departmentId = 0, excludeId = 0) {
    const [rows] = await pool.execute('CALL sp_get_potential_managers(?, ?, ?)', [
      searchTerm || '',
      departmentId || 0,
      excludeId || 0
    ]);
    return rows[0];
  }

  static async getById(id) {
    const [rows] = await pool.execute('CALL sp_get_employee_by_id(?)', [id]);
    return rows[0][0];
  }

  static async update(id, data) {
    const [rows] = await pool.execute(
      'CALL sp_update_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        data.organization_id || 1,
        data.employee_code || '',
        data.employee_name || '',
        data.employee_role || 0,
        data.designation_id || 0,
        data.employee_type || '',
        data.reporting_manager_id || null,
        data.joining_date || null,
        data.active !== undefined ? data.active : 1,
        data.modified_by || 'admin',
        data.department_id || 0
      ]
    );
    return rows[0][0];
  }

  static async delete(id) {
    await pool.execute('CALL sp_delete_employee(?)', [id]);
    return true;
  }
}

module.exports = EmployeeModel;
