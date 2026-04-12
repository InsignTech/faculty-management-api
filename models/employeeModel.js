const pool = require('../config/db');
const bcrypt = require('bcryptjs');
const UserModel = require('./userModel');

class EmployeeModel {
  static async create(data) {
    const [rows] = await pool.execute(
      'CALL sp_create_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        data.organization_id || 1,
        data.employee_code || '',
        data.employee_name || '',
        data.email || '',
        data.employee_role || 0,
        data.designation_id || 0,
        data.reporting_manager_id || null,
        data.joining_date || null,
        data.active !== undefined ? data.active : 1,
        data.created_by || 'admin',
        data.department_id || 0,
        data.basic_pay || 0.00
      ]
    );
    const employee = rows[0][0];

    // Create user account for new employee
    if (employee && employee.employee_id && data.email) {
      try {
        const defaultPassword = `${data.employee_code || 'User'}@123`;
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(defaultPassword, salt);
        
        await UserModel.signup(
          data.employee_name,
          data.email,
          hashedPassword,
          data.role_id || 1,
          employee.employee_id
        );
      } catch (err) {
        console.error('Failed to create user account for employee:', err.message);
        // We still return the employee as they were created, but log the error
      }
    }

    return employee;
  }

  static async getAll() {
    const query = `
      SELECT 
          e.*,
          d.departmentname,
          r.role AS role_name,
          des.designation AS designation_name,
          m.employee_name AS manager_name,
          mr.role AS manager_role
      FROM employee e
      LEFT JOIN department d ON e.department_id = d.department_id
      LEFT JOIN app_role r ON e.role_id = r.role_id
      LEFT JOIN designation des ON e.designation_id = des.designation_id
      LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
      LEFT JOIN app_role mr ON m.role_id = mr.role_id
      ORDER BY e.employee_id DESC
    `;
    const [rows] = await pool.execute(query);
    return rows;
  }

  static async getFiltered(searchTerm = '', roleId = 0) {
    const query = `
      SELECT 
          e.*,
          d.departmentname,
          r.role AS role_name,
          des.designation AS designation_name,
          m.employee_name AS manager_name,
          mr.role AS manager_role
      FROM employee e
      LEFT JOIN department d ON e.department_id = d.department_id
      LEFT JOIN app_role r ON e.role_id = r.role_id
      LEFT JOIN designation des ON e.designation_id = des.designation_id
      LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
      LEFT JOIN app_role mr ON m.role_id = mr.role_id
      WHERE 
          (? = '' OR e.employee_name LIKE CONCAT('%', ?, '%') OR e.employee_code LIKE CONCAT('%', ?, '%'))
          AND (? = 0 OR e.role_id = ?)
      ORDER BY e.employee_id DESC
    `;
    const term = searchTerm || '';
    const rId = roleId || 0;
    const [rows] = await pool.execute(query, [term, term, term, rId, rId]);
    return rows;
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
      'CALL sp_update_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        data.organization_id || 1,
        data.employee_code || '',
        data.employee_name || '',
        data.email || '',
        data.employee_role || 0,
        data.designation_id || 0,
        data.reporting_manager_id || null,
        data.joining_date || null,
        data.active !== undefined ? data.active : 1,
        data.modified_by || 'admin',
        data.department_id || 0,
        data.basic_pay || 0.00
      ]
    );
    const result = rows[0][0];

    // Update user account email if provided
    if (data.email) {
      try {
        await UserModel.updateEmailByEmployeeId(id, data.email);
      } catch (err) {
        console.error('Failed to sync email to user_accounts:', err.message);
      }
    }

    return result;
  }

  static async delete(id) {
    await pool.execute('CALL sp_delete_employee(?)', [id]);
    return true;
  }
  
  static async updateReportingManager(id, managerId) {
    const [result] = await pool.execute(
      'UPDATE employee SET reporting_manager_id = ? WHERE employee_id = ?',
      [managerId || null, id]
    );
    return result;
  }
}

module.exports = EmployeeModel;
