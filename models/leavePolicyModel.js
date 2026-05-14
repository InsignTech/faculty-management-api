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

    const newId = result.insertId;
    await this.logHistory(newId, { ...data, change_type: 'Created' });
    
    return { leave_policy_id: newId, ...data };
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

    await this.logHistory(id, { ...data, change_type: 'Updated' });

    return { leave_policy_id: id, ...data };
  }

  static async setActiveSystemPolicy(id, changedBy = 'admin') {
    await pool.execute('UPDATE leave_policy SET active = 0');
    await pool.execute('UPDATE leave_policy SET active = 1 WHERE leave_policy_id = ?', [id]);
    
    // Log activation in history
    const [rows] = await pool.execute('SELECT * FROM leave_policy WHERE leave_policy_id = ?', [id]);
    if (rows.length > 0) {
        await this.logHistory(id, { 
            ...rows[0], 
            policy_value: JSON.parse(rows[0].policy_value),
            created_by: changedBy, 
            change_type: 'Activated' 
        });
    }
    return true;
  }

  static async logHistory(policyId, data) {
    try {
        await pool.execute(
            'INSERT INTO leave_policy_history (leave_policy_id, policy_name, policy_value, start_date, end_date, changed_by, change_type) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [
                policyId,
                data.policy_name,
                JSON.stringify(data.policy_value),
                data.start_date,
                data.end_date || null,
                data.created_by || 'admin',
                data.change_type || 'Updated'
            ]
        );
    } catch (err) {
        console.error('Failed to log policy history:', err);
    }
  }

  static async deleteSystemPolicy(id) {
    await pool.execute('DELETE FROM leave_policy WHERE leave_policy_id = ?', [id]);
    return true;
  }

  static async getPolicyHistory(id = null) {
    let query = 'SELECT *, DATE_FORMAT(changed_on, "%Y-%m-%d %H:%i:%s") as changed_on FROM leave_policy_history';
    const params = [];
    if (id) {
        query += ' WHERE leave_policy_id = ?';
        params.push(id);
    }
    query += ' ORDER BY changed_on DESC LIMIT 100';
    const [rows] = await pool.execute(query, params);
    return rows;
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
  static async getEffectivePolicy(employeeId, targetDate = null) {
    const dateValue = targetDate ? `'${targetDate}'` : 'CURDATE()';
    // 1. Get Employee Details (to get their role_id)
    const [empRows] = await pool.execute('SELECT role_id FROM employee WHERE employee_id = ?', [employeeId]);
    if (empRows.length === 0) return null;
    const roleId = empRows[0].role_id;

    // 2. Fetch the most relevant Global Policy
    // Priority: Active = 1, otherwise the one that covers the date, else first one
    const [globalPolicies] = await pool.execute(`
      SELECT *, policy_value 
      FROM leave_policy 
      ORDER BY active DESC, 
               (${dateValue} BETWEEN start_date AND COALESCE(end_date, '9999-12-31')) DESC, 
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

  /**
   * CALCULATE ACCRUAL
   * Runs monthly to credit leaves based on effective policies.
   * @param {boolean} dryRun - If true, returns calculation result without saving to DB.
   */
  static async calculateAccrual(dryRun = false, targetDate = null) {
    const [employees] = await pool.execute('SELECT employee_id, employee_name FROM employee WHERE active = 1');
    const now = targetDate ? new Date(targetDate) : new Date();
    const currentMonth = now.getMonth() + 1; // 1-12
    const currentYear = now.getFullYear();
    const monthYear = `${String(currentMonth).padStart(2, '0')}-${currentYear}`;
    
    // Fetch Year Start Month from settings (Default 1 - January)
    let startMonth = 1;
    try {
        const [settings] = await pool.execute('SELECT settings_value FROM settings WHERE settings_key = "leave_year_start_month"');
        if (settings.length > 0) startMonth = parseInt(settings[0].settings_value) || 1;
    } catch (e) {
        // Fallback to 1
    }

    const prevDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const prevMonthYear = `${String(prevDate.getMonth() + 1).padStart(2, '0')}-${prevDate.getFullYear()}`;

    const report = [];

    for (const emp of employees) {
      const empId = emp.employee_id;
      const sqlTargetDate = now.toISOString().split('T')[0];
      const effectivePolicy = await this.getEffectivePolicy(empId, sqlTargetDate);
      if (!effectivePolicy) continue;

      const policyValue = effectivePolicy.policy_value || [];
      const empReport = { employee_id: empId, name: emp.employee_name, credits: [] };
      
      for (const item of policyValue) {
        const leaveType = item.leaveType;
        let creditAmount = 0;
        const freq = item.creditFrequency || item.cappingType; // Standardizing to creditFrequency
        
        // 1. ADVANCED YTD SYNC LOGIC
        // We ensure that the TOTAL leaves credited in the current period/year match the policy.
        
        let targetTotalYTD = 0;
        const interval = freq === 'Quarterly' ? 3 : freq === 'Half Yearly' ? 6 : freq === 'Yearly' ? 12 : 1;
        
        if (freq === 'Monthly') {
            targetTotalYTD = 0; // Not YTD based
            creditAmount = parseFloat(item.cappingCount || 0);
        } else {
            // How many intervals have passed in the current year?
            const monthsSinceStart = (currentMonth - startMonth + 12) % 12;
            const intervalsPassed = Math.floor(monthsSinceStart / interval) + 1;
            targetTotalYTD = intervalsPassed * (freq === 'Yearly' ? parseFloat(item.leaveCount || 0) : parseFloat(item.cappingCount || 0));
            
            const [yearRecords] = await pool.execute(
                'SELECT SUM(credited_count) as total FROM employee_leaves WHERE emp_id = ? AND leave_type = ? AND month_year LIKE ?',
                [empId, leaveType, `%-${currentYear}`]
            );
            const totalYTD = parseFloat(yearRecords[0].total || 0);
            
            const [currentRecord] = await pool.execute(
                'SELECT credited_count FROM employee_leaves WHERE emp_id = ? AND leave_type = ? AND month_year = ?',
                [empId, leaveType, monthYear]
            );
            const alreadyCreditedThisMonth = currentRecord.length > 0 ? parseFloat(currentRecord[0].credited_count) : 0;
            
            // Correction Logic
            if (totalYTD !== targetTotalYTD) {
                creditAmount = targetTotalYTD - (totalYTD - alreadyCreditedThisMonth);
            } else {
                creditAmount = alreadyCreditedThisMonth;
            }
        }

        // 2. BALANCE CASCADING (Crucial for Backdated Leaves)
        const [prevRecord] = await pool.execute(
          'SELECT balance_leave FROM employee_leaves WHERE emp_id = ? AND leave_type = ? AND month_year = ?',
          [empId, leaveType, prevMonthYear]
        );
        
        let previousBalance = prevRecord.length > 0 ? parseFloat(prevRecord[0].balance_leave) : 0;
        let openingLeave = 0;

        if (currentMonth === startMonth) {
            const action = item.yearEndAction || 'Lap';
            if (action === 'Carry Forward') {
                openingLeave = previousBalance;
                const limit = parseFloat(item.maxCarryForward || 0);
                if (limit > 0 && openingLeave > limit) openingLeave = limit;
            } else {
                openingLeave = 0;
            }
        } else {
            // CASCADE: Always pull the fresh balance from last month
            openingLeave = previousBalance;
            // If the policy says no carry forward (monthly lapse), we force 0
            if (!(item.carryForward === true || item.carryForward === 1 || item.carryForward === 'true')) {
                openingLeave = 0;
            }
        }

        // 3. CAP CHECK
        const maxCap = parseFloat(item.maxAccumulation || 0);
        if (maxCap > 0 && (openingLeave + creditAmount) > maxCap) {
            creditAmount = Math.max(0, maxCap - openingLeave);
        }

        // 4. PERSISTENCE & SOURCE-OF-TRUTH SYNC (Calculate leaves actually taken in this month)
        const [requests] = await pool.execute(`
            SELECT SUM(total_days) as taken 
            FROM leave_requests 
            WHERE employee_id = ? 
            AND leave_type = ? 
            AND status = 'Approved' 
            AND DATE_FORMAT(start_date, '%m-%Y') = ?
        `, [empId, leaveType, monthYear]);
        
        const leavesTaken = parseFloat(requests[0].taken || 0);

        const [existing] = await pool.execute(
            'SELECT id FROM employee_leaves WHERE emp_id = ? AND leave_type = ? AND month_year = ?',
            [empId, leaveType, monthYear]
        );

        if (creditAmount !== 0 || openingLeave !== 0 || existing.length > 0) {
          const total = openingLeave + creditAmount;
          const balance = total - leavesTaken;

          empReport.credits.push({
            leaveType,
            openingLeave,
            creditAmount,
            leavesTaken,
            total,
            balance
          });

          if (!dryRun) {
            await pool.execute(`
              INSERT INTO employee_leaves 
                (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
              VALUES (?, ?, ?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE 
                credited_count = VALUES(credited_count),
                opening_leave = VALUES(opening_leave),
                leaves_taken = VALUES(leaves_taken)
            `, [empId, leaveType, monthYear, openingLeave, creditAmount, leavesTaken]);
          }
        }
      }
      if (empReport.credits.length > 0) report.push(empReport);
    }
    return dryRun ? report : true;
  }
}

module.exports = LeavePolicyModel;
