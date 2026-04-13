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

  static async getAll(limit = 10, offset = 0) {
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
      LIMIT ? OFFSET ?
    `;
    const [rows] = await pool.execute(query, [limit.toString(), offset.toString()]);
    return rows;
  }

  static async getFiltered(searchTerm = '', roleId = 0, limit = 10, offset = 0, managerId = 0) {
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
          AND (? = 0 OR e.reporting_manager_id = ?)
      ORDER BY e.employee_id DESC
      LIMIT ? OFFSET ?
    `;
    const term = searchTerm || '';
    const rId = roleId || 0;
    const mId = managerId || 0;
    const [rows] = await pool.execute(query, [
        term, term, term, 
        rId, rId, 
        mId, mId,
        limit.toString(), 
        offset.toString()
    ]);
    return rows;
  }

  static async getTotalCount(searchTerm = '', roleId = 0, managerId = 0) {
    const query = `
      SELECT COUNT(*) as total
      FROM employee e
      WHERE 
          (? = '' OR e.employee_name LIKE CONCAT('%', ?, '%') OR e.employee_code LIKE CONCAT('%', ?, '%'))
          AND (? = 0 OR e.role_id = ?)
          AND (? = 0 OR e.reporting_manager_id = ?)
    `;
    const term = searchTerm || '';
    const rId = roleId || 0;
    const mId = managerId || 0;
    const [rows] = await pool.execute(query, [term, term, term, rId, rId, mId, mId]);
    return rows[0].total;
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

  static async getSubordinates(managerId) {
    const query = `
      WITH RECURSIVE subordinates AS (
          SELECT employee_id, employee_name, employee_code, reporting_manager_id, role_id, department_id, designation_id, email
          FROM employee
          WHERE reporting_manager_id = ?
          UNION ALL
          SELECT e.employee_id, e.employee_name, e.employee_code, e.reporting_manager_id, e.role_id, e.department_id, e.designation_id, e.email
          FROM employee e
          INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
      )
      SELECT 
        s.*,
        d.departmentname,
        r.role AS role_name,
        des.designation AS designation_name
      FROM subordinates s
      LEFT JOIN department d ON s.department_id = d.department_id
      LEFT JOIN app_role r ON s.role_id = r.role_id
      LEFT JOIN designation des ON s.designation_id = des.designation_id
      ORDER BY s.employee_name ASC;
    `;
    const [rows] = await pool.execute(query, [managerId]);
    return rows;
  }

  static async isSubordinate(managerId, targetId) {
    if (!managerId || !targetId) return false;
    const query = `
      WITH RECURSIVE subordinates AS (
          SELECT employee_id
          FROM employee
          WHERE reporting_manager_id = ?
          UNION ALL
          SELECT e.employee_id
          FROM employee e
          INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
      )
      SELECT COUNT(*) as count FROM subordinates WHERE employee_id = ?;
    `;
    const [rows] = await pool.execute(query, [managerId, targetId]);
    return rows[0].count > 0;
  }
}

module.exports = EmployeeModel;
