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
    const { employee_id, leave_type, start_date, end_date, leave_half_type, reason, attachment_path, total_days } = data;
    
    const halfType = leave_half_type || 'FullDay';
    const requestedDays = halfType !== 'FullDay' ? 0.5 : (total_days || 0);

    // 1. Balance Validation
    const balance = await this.getLeaveBalance(employee_id, new Date(start_date));
    const leaveBalance = balance.find(b => b.leaveType === leave_type);
    
    if (!leaveBalance) {
      throw new Error(`No policy found for leave type: ${leave_type}`);
    }

    if (leaveBalance.available < requestedDays) {
      throw new Error(`Insufficient balance for ${leave_type}. Available: ${leaveBalance.available}, Requested: ${requestedDays}`);
    }

    // 2. Overlap Validation (Smart Half-Day Aware)
    const [overlaps] = await pool.execute(
      `SELECT start_date, end_date, leave_half_type, status 
       FROM leave_requests 
       WHERE employee_id = ? 
         AND status IN ('Pending', 'Approved')
         AND (? <= end_date AND ? >= start_date)`,
      [employee_id, start_date, end_date]
    );

    if (overlaps.length > 0) {
      const isConflict = overlaps.some(existing => {
        // If existing is FullDay, it always conflicts
        if (existing.leave_half_type === 'FullDay') return true;
        // If new is FullDay, it conflicts with any existing on that date
        if (halfType === 'FullDay') return true;
        // If both are the same half, they conflict
        if (existing.leave_half_type === halfType) return true;
        return false;
      });

      if (isConflict) {
        throw new Error('Leave request overlaps with an existing pending or approved leave.');
      }
    }

    // 3. Call SP to apply leave
    const [rows] = await pool.execute(
      'CALL sp_apply_leave(?, ?, ?, ?, ?, ?, ?)',
      [
        employee_id,
        leave_type,
        start_date,
        end_date,
        halfType,
        reason,
        attachment_path || null
      ]
    );
    
    const result = rows[0][0];

    // Double check total_days update
    if (result && result.leave_request_id && (!result.total_days || result.total_days == 0)) {
       if (halfType !== 'FullDay') {
          await pool.execute(
            'UPDATE leave_requests SET total_days = 0.5 WHERE leave_request_id = ?',
            [result.leave_request_id]
          );
       } else if (total_days > 0) {
          await pool.execute(
            'UPDATE leave_requests SET total_days = ? WHERE leave_request_id = ?',
            [total_days, result.leave_request_id]
          );
       }
    }

    return result;
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

    const policyYear = policyStart.getFullYear();

    // 2. Get leaves used in current policy year — split by status.
    // Using YEAR() instead of strict date range to avoid UTC/IST timezone shifts
    // where a Jan 1 IST leave gets stored as Dec 31 UTC and gets excluded.
    const [leavesTaken] = await pool.execute(
      `SELECT leave_type, status, SUM(total_days) as taken 
       FROM leave_requests 
       WHERE employee_id = ? 
         AND status IN ('Approved', 'Pending')
         AND YEAR(start_date) = ?
       GROUP BY leave_type, status`,
      [employeeId, policyYear]
    );

    // Build separate maps for approved and pending
    // Use += accumulation to safely handle multiple rows per type
    const approvedMap = {};
    const pendingMap = {};
    leavesTaken.forEach(row => {
      const days = parseFloat(row.taken) || 0;
      if (row.status === 'Approved') approvedMap[row.leave_type] = (approvedMap[row.leave_type] || 0) + days;
      if (row.status === 'Pending')  pendingMap[row.leave_type]  = (pendingMap[row.leave_type]  || 0) + days;
    });

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
      const maxWithCarry = parseFloat(item.leaveCount) * 2;
      const effectiveAllocated = Math.min(allocated + carried, maxWithCarry);

      const approved = approvedMap[item.leaveType] || 0;
      const pending  = pendingMap[item.leaveType]  || 0;
      const totalDeducted = approved + pending;

      return {
        leaveType: item.leaveType,
        totalAllocated: parseFloat(item.leaveCount),
        carryForward: carried,
        currentlyEarned: effectiveAllocated,
        used: approved,           // Only approved leaves count as "used"
        pending: pending,         // Pending days reserved but not yet confirmed
        available: Math.max(0, effectiveAllocated - totalDeducted), // Pending reserves days
        strategy: item.cappingType
      };
    });

    return balance;
  }
}

module.exports = LeaveRequestModel;
