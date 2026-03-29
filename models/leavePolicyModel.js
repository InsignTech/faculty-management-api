const pool = require('../config/db');

class LeavePolicyModel {
  // --- System Level ---
  static async getAllSystemPolicies() {
    const [rows] = await pool.execute('CALL sp_get_leave_policies()');
    return rows[0];
  }

  static async createSystemPolicy(data) {
    const [rows] = await pool.execute(
      'CALL sp_create_leave_policy(?, ?, ?, ?)',
      [
        data.policy_name,
        data.policy_year,
        JSON.stringify(data.policy_value),
        data.created_by || 'admin'
      ]
    );
    return rows[0][0];
  }

  static async updateSystemPolicy(id, data) {
    const [rows] = await pool.execute(
      'CALL sp_update_leave_policy(?, ?, ?, ?)',
      [
        id,
        data.policy_name,
        data.policy_year,
        JSON.stringify(data.policy_value)
      ]
    );
    return rows[0][0];
  }

  static async setActiveSystemPolicy(id) {
    const [rows] = await pool.execute('CALL sp_set_active_leave_policy(?)', [id]);
    return rows[0][0];
  }

  static async deleteSystemPolicy(id) {
    const [rows] = await pool.execute('CALL sp_delete_leave_policy(?)', [id]);
    return rows[0][0];
  }

  // --- Designation Level ---
  static async getDesignationPolicy(designationId) {
    const [rows] = await pool.execute('CALL sp_get_designation_policy(?)', [designationId]);
    const policy = rows[0][0];
    if (policy && policy.policy_value) {
      policy.policy_value = JSON.parse(policy.policy_value);
    }
    return policy;
  }

  static async saveDesignationPolicy(data) {
    const [rows] = await pool.execute(
      'CALL sp_save_designation_policy(?, ?, ?, ?)',
      [
        data.leave_policy_id,
        data.designation_id,
        JSON.stringify(data.policy_value),
        data.created_by || 'admin'
      ]
    );
    return rows[0][0];
  }

  // --- Employee Level ---
  static async getEmployeePolicy(employeeId) {
    const [rows] = await pool.execute('CALL sp_get_employee_policy(?)', [employeeId]);
    const policy = rows[0][0];
    if (policy && policy.policy_value) {
      policy.policy_value = JSON.parse(policy.policy_value);
    }
    return policy;
  }

  static async saveEmployeePolicy(data) {
    const [rows] = await pool.execute(
      'CALL sp_save_employee_policy(?, ?, ?, ?)',
      [
        data.leave_policy_id,
        data.employee_id,
        JSON.stringify(data.policy_value),
        data.created_by || 'admin'
      ]
    );
    return rows[0][0];
  }
}

module.exports = LeavePolicyModel;
