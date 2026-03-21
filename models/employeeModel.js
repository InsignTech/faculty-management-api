const pool = require('../config/db');

class EmployeeModel {
  static async create(data) {
    const [rows] = await pool.execute(
      'CALL sp_create_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        data.organization_id || 1,
        data.employee_code,
        data.employee_name,
        data.employee_role,
        data.employee_type,
        data.reporting_manager_id || null,
        data.joining_date,
        data.active ? 1 : 0,
        data.created_by || 'system',
        data.department_id
      ]
    );
    return rows[0][0];
  }

  static async getAll() {
    const [rows] = await pool.execute('CALL sp_get_employees()');
    return rows[0];
  }

  static async getById(id) {
    const [rows] = await pool.execute('CALL sp_get_employee_by_id(?)', [id]);
    return rows[0][0];
  }

  static async update(id, data) {
    const [rows] = await pool.execute(
      'CALL sp_update_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        data.organization_id || 1,
        data.employee_code,
        data.employee_name,
        data.employee_role,
        data.employee_type,
        data.reporting_manager_id || null,
        data.joining_date,
        data.active ? 1 : 0,
        data.modified_by || 'system',
        data.department_id
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
