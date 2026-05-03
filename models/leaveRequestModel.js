const pool = require('../config/db');
const LeavePolicyModel = require('./leavePolicyModel');

class LeaveRequestModel {
  static async getAll(filters = {}) {
    let sql = `
      SELECT lr.*, e.employee_name, e.employee_code as emp_code
      FROM leave_requests lr
      JOIN employee e ON lr.employee_id = e.employee_id
      WHERE 1=1
    `;
    const params = [];

    if (filters.status) {
      sql += ' AND lr.status = ?';
      params.push(filters.status);
    }

    if (filters.employee_id) {
      sql += ' AND lr.employee_id = ?';
      params.push(filters.employee_id);
    }

    sql += ' ORDER BY lr.applied_on DESC';
    const [rows] = await pool.execute(sql, params);
    return rows;
  }

  static async getForSuperior(superiorId) {
    const sql = `
      SELECT lr.*, e.employee_name, e.employee_code as emp_code
      FROM leave_requests lr
      JOIN employee e ON lr.employee_id = e.employee_id
      WHERE e.reporting_manager_id = ?
      ORDER BY lr.applied_on DESC
    `;
    const [rows] = await pool.execute(sql, [superiorId]);
    return rows;
  }

  static create = async (data) => {
    const { employee_id, leave_type, start_date, end_date, leave_half_type, reason, attachment_path } = data;
    const [rows] = await pool.execute(
      'CALL sp_apply_leave(?, ?, ?, ?, ?, ?, ?)',
      [
        employee_id,
        leave_type,
        start_date,
        end_date,
        leave_half_type || 'FullDay',
        reason,
        attachment_path || null
      ]
    );
    // The SP returns a result set with leave_request_id, total_days, and status
    return rows[0][0];
  };

  static async getById(id) {
    const [rows] = await pool.execute('SELECT * FROM leave_requests WHERE leave_request_id = ?', [id]);
    return rows[0];
  }

  static async updateStatus(id, status, data) {
    const { approved_by_id, rejection_reason } = data;
    const [rows] = await pool.execute(
      'CALL sp_approve_leave(?, ?, ?, ?)',
      [
        id,
        approved_by_id,
        status,
        rejection_reason || null
      ]
    );
    return rows[0][0];
  }

  /**
   * CALCULATE LEAVE BALANCE
   * Handles: Yearly/Monthly accumulation, carry forward from prior period
   */
  static async getLeaveBalance(employeeId, date = new Date()) {
    // 1. Get the effective policy for this employee
    const policy = await LeavePolicyModel.getEffectivePolicy(employeeId, date);
    if (!policy) return [];

    const policyValue = policy.policy_value || [];
    const policyStart = new Date(policy.start_date);
    const policyEnd = policy.end_date ? new Date(policy.end_date) : null;

    // 2. Get leaves used in current policy period
    const [leavesTaken] = await pool.execute(
      `SELECT leave_type, SUM(total_days) as taken 
       FROM leave_requests 
       WHERE employee_id = ? 
         AND status = 'Approved' 
         AND start_date >= ?
         ${policyEnd ? 'AND end_date <= ?' : ''}
       GROUP BY leave_type`,
      policyEnd
        ? [employeeId, policy.start_date, policy.end_date]
        : [employeeId, policy.start_date]
    );

    const takenMap = leavesTaken.reduce((acc, curr) => {
      acc[curr.leave_type] = parseFloat(curr.taken);
      return acc;
    }, {});

    // 3. Get carry-forward from the PREVIOUS policy period (if applicable)
    // Find the prior active policy that ended before this one started
    const [priorPolicies] = await pool.execute(
      `SELECT * FROM leave_policy 
       WHERE end_date < ? AND (active = 1 OR leave_policy_id != ?)
       ORDER BY end_date DESC LIMIT 1`,
      [policy.start_date, policy.leave_policy_id]
    );

    const carryForwardMap = {};
    if (priorPolicies.length > 0) {
      const priorPolicy = priorPolicies[0];
      const priorPolicyValue = JSON.parse(priorPolicy.policy_value || '[]');

      // Get what was used in the prior period
      const [priorTaken] = await pool.execute(
        `SELECT leave_type, SUM(total_days) as taken 
         FROM leave_requests 
         WHERE employee_id = ? AND status = 'Approved' 
           AND start_date >= ? AND end_date <= ?
         GROUP BY leave_type`,
        [employeeId, priorPolicy.start_date, priorPolicy.end_date]
      );
      const priorTakenMap = priorTaken.reduce((acc, curr) => {
        acc[curr.leave_type] = parseFloat(curr.taken);
        return acc;
      }, {});

      // Carry forward = prior allocated - prior used (only for types with carryForward enabled)
      priorPolicyValue.forEach(item => {
        if (item.carryForward) {
          const priorAllocated = parseFloat(item.leaveCount);
          const priorUsed = priorTakenMap[item.leaveType] || 0;
          const surplus = Math.max(0, priorAllocated - priorUsed);
          if (surplus > 0) carryForwardMap[item.leaveType] = surplus;
        }
      });
    }

    // 4. Calculate current entitlement
    const now = new Date();
    const balance = policyValue.map(item => {
      let allocated = parseFloat(item.leaveCount);

      if (item.cappingType === 'Monthly') {
        // +1 to include the current month (so day 1 of the policy = 1 month earned)
        const monthsElapsed = (now.getFullYear() - policyStart.getFullYear()) * 12
          + (now.getMonth() - policyStart.getMonth()) + 1;
        const earnedPerMonth = parseFloat(item.cappingCount || 0);
        allocated = Math.min(allocated, monthsElapsed * earnedPerMonth);
      }

      // Add carry-forward on top, capped so total doesn't exceed leaveCount * 2
      const carried = carryForwardMap[item.leaveType] || 0;
      const maxWithCarry = parseFloat(item.leaveCount) * 2; // sensible cap
      const effectiveAllocated = Math.min(allocated + carried, maxWithCarry);

      const used = takenMap[item.leaveType] || 0;
      return {
        leaveType: item.leaveType,
        totalAllocated: parseFloat(item.leaveCount),
        carryForward: carried,
        currentlyEarned: effectiveAllocated,
        used: used,
        available: Math.max(0, effectiveAllocated - used),
        strategy: item.cappingType
      };
    });

    return balance;
  }
}

module.exports = LeaveRequestModel;
