const pool = require('../config/db');

class LeavePolicyModel {
  // --- System Level ---
  static async getAllSystemPolicies() {
    const [rows] = await pool.execute('SELECT *, DATE_FORMAT(start_date, "%Y-%m-%d") as start_date, DATE_FORMAT(end_date, "%Y-%m-%d") as end_date FROM leave_policy ORDER BY start_date DESC');
    return rows;
  }

  static async isOverlapping(startDate, endDate, excludeId = null) {
    let query = `
      SELECT COUNT(*) as count 
      FROM leave_policy 
      WHERE (
        ? <= COALESCE(end_date, '9999-12-31') AND 
        start_date <= ?
      )
    `;
    const params = [startDate, endDate || '9999-12-31'];

    if (excludeId) {
      query += ' AND leave_policy_id != ?';
      params.push(excludeId);
    }

    const [rows] = await pool.execute(query, params);
    return rows[0].count > 0;
  }

  static async createSystemPolicy(data) {
    if (await this.isOverlapping(data.start_date, data.end_date)) {
      throw new Error('Policy dates overlap with an existing policy');
    }

    const [result] = await pool.execute(
      'INSERT INTO leave_policy (policy_name, start_date, end_date, policy_value, active, created_by, created_on) VALUES (?, ?, ?, ?, ?, ?, NOW())',
      [
        data.policy_name,
        data.start_date,
        data.end_date || null,
        JSON.stringify(data.policy_value),
        data.active ? 1 : 0,
        data.created_by || 'admin'
      ]
    );
    return { leave_policy_id: result.insertId, ...data };
  }

  static async updateSystemPolicy(id, data) {
    if (await this.isOverlapping(data.start_date, data.end_date, id)) {
      throw new Error('Policy dates overlap with an existing policy');
    }

    await pool.execute(
      'UPDATE leave_policy SET policy_name = ?, start_date = ?, end_date = ?, policy_value = ? WHERE leave_policy_id = ?',
      [
        data.policy_name,
        data.start_date,
        data.end_date || null,
        JSON.stringify(data.policy_value),
        id
      ]
    );
    return { leave_policy_id: id, ...data };
  }

  static async setActiveSystemPolicy(id) {
    await pool.execute('UPDATE leave_policy SET active = 0');
    await pool.execute('UPDATE leave_policy SET active = 1 WHERE leave_policy_id = ?', [id]);
    return true;
  }

  static async deleteSystemPolicy(id) {
    await pool.execute('DELETE FROM leave_policy WHERE leave_policy_id = ?', [id]);
    return true;
  }

  // --- Role Level ---
  static async getRolePolicy(roleId) {
    const [rows] = await pool.execute('SELECT * FROM leave_policy_role WHERE role_id = ? AND active = 1', [roleId]);
    const policy = rows[0];
    if (policy && policy.policy_value) {
      policy.policy_value = JSON.parse(policy.policy_value);
    }
    return policy;
  }

  static async saveRolePolicy(data) {
    // Check if exists
    const [existing] = await pool.execute('SELECT leave_policy_role_id FROM leave_policy_role WHERE role_id = ?', [data.role_id]);
    
    if (existing.length > 0) {
      await pool.execute(
        'UPDATE leave_policy_role SET leave_policy_id = ?, policy_value = ? WHERE role_id = ?',
        [data.leave_policy_id, JSON.stringify(data.policy_value), data.role_id]
      );
    } else {
      await pool.execute(
        'INSERT INTO leave_policy_role (leave_policy_id, role_id, policy_value, active, created_by, created_on) VALUES (?, ?, ?, 1, ?, NOW())',
        [data.leave_policy_id, data.role_id, JSON.stringify(data.policy_value), data.created_by || 'admin']
      );
    }
    return true;
  }

  // --- Employee Level ---
  static async getEmployeePolicy(employeeId) {
    const [rows] = await pool.execute('SELECT * FROM leave_policy_employee WHERE employee_id = ? AND active = 1', [employeeId]);
    const policy = rows[0];
    if (policy && policy.policy_value) {
      policy.policy_value = JSON.parse(policy.policy_value);
    }
    return policy;
  }

  static async saveEmployeePolicy(data) {
    const [existing] = await pool.execute('SELECT leave_policy_employee_id FROM leave_policy_employee WHERE employee_id = ?', [data.employee_id]);
    
    if (existing.length > 0) {
      await pool.execute(
        'UPDATE leave_policy_employee SET leave_policy_id = ?, policy_value = ? WHERE employee_id = ?',
        [data.leave_policy_id, JSON.stringify(data.policy_value), data.employee_id]
      );
    } else {
      await pool.execute(
        'INSERT INTO leave_policy_employee (leave_policy_id, employee_id, policy_value, active, created_by, created_on) VALUES (?, ?, ?, 1, ?, NOW())',
        [data.leave_policy_id, data.employee_id, JSON.stringify(data.policy_value), data.created_by || 'admin']
      );
    }
    return true;
  }

  /**
   * GET EFFECTIVE POLICY (The Core Logic)
   * Priority: Employee > Role > Global
   */
  static async getEffectivePolicy(employeeId) {
    // 1. Get Employee Details (to get their role_id)
    const [empRows] = await pool.execute('SELECT role_id FROM employee WHERE employee_id = ?', [employeeId]);
    if (empRows.length === 0) return null;
    const roleId = empRows[0].role_id;

    // 2. Fetch all levels
    const [globalPolicy] = await pool.execute('SELECT policy_value FROM leave_policy WHERE active = 1 LIMIT 1');
    const [rolePolicy] = await pool.execute('SELECT policy_value FROM leave_policy_role WHERE role_id = ? AND active = 1', [roleId]);
    const [empPolicy] = await pool.execute('SELECT policy_value FROM leave_policy_employee WHERE employee_id = ? AND active = 1', [employeeId]);

    const mergePolicies = (base, overrides) => {
      const baseArr = base ? JSON.parse(base) : [];
      const overArr = overrides ? JSON.parse(overrides) : [];
      
      const merged = {};
      // Add base values
      baseArr.forEach(item => merged[item.leaveType] = item);
      // Override with higher level values (Role or Employee)
      overArr.forEach(item => merged[item.leaveType] = item);
      
      return Object.values(merged);
    };

    let effectivePolicy = globalPolicy.length > 0 ? JSON.parse(globalPolicy[0].policy_value) : [];
    
    // Merge Role over Global
    if (rolePolicy.length > 0) {
      effectivePolicy = mergePolicies(JSON.stringify(effectivePolicy), rolePolicy[0].policy_value);
    }

    // Merge Employee over (Role+Global)
    if (empPolicy.length > 0) {
      effectivePolicy = mergePolicies(JSON.stringify(effectivePolicy), empPolicy[0].policy_value);
    }

    return effectivePolicy;
  }
}

module.exports = LeavePolicyModel;
