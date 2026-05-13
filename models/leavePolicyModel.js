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

    // 2. Fetch the most relevant Global Policy
    // Priority: Active = 1, otherwise the one that covers the current date, else first one
    const [globalPolicies] = await pool.execute(`
      SELECT *, policy_value 
      FROM leave_policy 
      ORDER BY active DESC, 
               (CURDATE() BETWEEN start_date AND COALESCE(end_date, '9999-12-31')) DESC, 
               start_date DESC 
      LIMIT 1
    `);

    if (globalPolicies.length === 0) return null;
    const globalPolicy = globalPolicies[0];

    // 3. Fetch overrides
    const [rolePolicy] = await pool.execute('SELECT policy_value FROM leave_policy_role WHERE role_id = ? AND leave_policy_id = ?', [roleId, globalPolicy.leave_policy_id]);
    const [empPolicy] = await pool.execute('SELECT policy_value FROM leave_policy_employee WHERE employee_id = ? AND leave_policy_id = ?', [employeeId, globalPolicy.leave_policy_id]);

    const mergePolicies = (baseArr, overArr) => {
      const merged = {};
      // Add base values
      baseArr.forEach(item => merged[item.leaveType] = item);
      // Override with higher level values (Role or Employee)
      overArr.forEach(item => merged[item.leaveType] = item);
      
      return Object.values(merged);
    };

    let effectiveValue = JSON.parse(globalPolicy.policy_value || '[]');
    
    // Merge Role over Global
    if (rolePolicy.length > 0 && rolePolicy[0].policy_value) {
      effectiveValue = mergePolicies(effectiveValue, JSON.parse(rolePolicy[0].policy_value));
    }

    // Merge Employee over (Role+Global)
    if (empPolicy.length > 0 && empPolicy[0].policy_value) {
      effectiveValue = mergePolicies(effectiveValue, JSON.parse(empPolicy[0].policy_value));
    }

    return {
      ...globalPolicy,
      policy_value: effectiveValue,
      start_date: globalPolicy.start_date,
      end_date: globalPolicy.end_date
    };
  }

  static async calculateAccrual() {
    // 1. Get all active employees
    const [employees] = await pool.execute('SELECT employee_id FROM employee WHERE active = 1');
    const now = new Date();
    const currentMonth = now.getMonth() + 1; // 1-12
    const currentYear = now.getFullYear();
    const monthYear = `${String(currentMonth).padStart(2, '0')}-${currentYear}`;
    
    // Calculate previous month for carry forward
    const prevDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const prevMonthYear = `${String(prevDate.getMonth() + 1).padStart(2, '0')}-${prevDate.getFullYear()}`;

    for (const emp of employees) {
      const empId = emp.employee_id;
      const effectivePolicy = await this.getEffectivePolicy(empId);
      if (!effectivePolicy) continue;

      const policyValue = effectivePolicy.policy_value || [];
      
      for (const item of policyValue) {
        const leaveType = item.leaveType;
        let creditAmount = 0;

        const freq = item.creditFrequency || item.cappingType;
        
        if (freq === 'Monthly') {
          creditAmount = parseFloat(item.cappingCount || 0);
        } else if (freq === 'Quarterly') {
          const quarterLimit = parseInt(item.quarterLimit) || 3;
          if (currentMonth % quarterLimit === 1) { 
            creditAmount = parseFloat(item.cappingCount || 0);
          }
        } else if (freq === 'Half Yearly') {
          if (currentMonth === 1 || currentMonth === 7) {
            creditAmount = parseFloat(item.cappingCount || 0);
          }
        } else if (freq === 'Yearly') {
          if (currentMonth === 1) { 
            creditAmount = parseFloat(item.leaveCount || 0);
          }
        }

        // --- CARRY FORWARD / IDEMPOTENT CREDIT LOGIC ---
        // 1. Check for previous month's balance to carry forward
        const [prevRecord] = await pool.execute(
          'SELECT balance_leave FROM employee_leaves WHERE emp_id = ? AND leave_type = ? AND month_year = ?',
          [empId, leaveType, prevMonthYear]
        );
        
        let openingLeave = 0;
        if (prevRecord.length > 0) {
            openingLeave = parseFloat(prevRecord[0].balance_leave);
        } else {
            // Initial Catch-up: If no history, credit full amount for setup
            if (creditAmount === 0) {
                creditAmount = (freq === 'Yearly') ? parseFloat(item.leaveCount || 0) : parseFloat(item.cappingCount || 0);
            }
        }

        // 2. Perform Upsert (Insert or Update if already exists)
        // If re-running, this will update the credited_count to the latest policy value
        if (creditAmount > 0 || openingLeave > 0) {
          await pool.execute(`
            INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
            VALUES (?, ?, ?, ?, ?, 0)
            ON DUPLICATE KEY UPDATE 
              credited_count = VALUES(credited_count),
              opening_leave = VALUES(opening_leave)
          `, [empId, leaveType, monthYear, openingLeave, creditAmount]);
        }
      }
    }
    return true;
  }
}

module.exports = LeavePolicyModel;
