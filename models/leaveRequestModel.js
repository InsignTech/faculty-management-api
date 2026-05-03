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

  static async getById(id) {
    const [rows] = await pool.execute('SELECT * FROM leave_requests WHERE leave_request_id = ?', [id]);
    return rows[0];
  }

  static async updateStatus(id, status, data) {
    const { approved_by_id, rejection_reason } = data;
    await pool.execute(
      'UPDATE leave_requests SET status = ?, approved_by_id = ?, approved_on = NOW(), rejection_reason = ? WHERE leave_request_id = ?',
      [status, approved_by_id, rejection_reason || null, id]
    );
    return true;
  }

  /**
   * CALCULATE LEAVE BALANCE
   * The core engine that respects our new hierarchy
   */
  static async getLeaveBalance(employeeId, date = new Date()) {
    // 1. Get the effective policy for this employee
    const policy = await LeavePolicyModel.getEffectivePolicy(employeeId, date);
    if (!policy) return [];

    const policyValue = policy.policy_value || [];
    
    // 2. Get all approved leaves for this employee in the policy's date range
    const [leavesTaken] = await pool.execute(
      'SELECT leave_type, SUM(total_days) as taken FROM leave_requests WHERE employee_id = ? AND status = "Approved" AND start_date >= ? AND (end_date <= ? OR ? IS NULL) GROUP BY leave_type',
      [employeeId, policy.start_date, policy.end_date, policy.end_date]
    );

    const takenMap = leavesTaken.reduce((acc, curr) => {
      acc[curr.leave_type] = parseFloat(curr.taken);
      return acc;
    }, {});

    // 3. Calculate current entitlement based on accumulation strategy
    const balance = policyValue.map(item => {
      let allocated = parseFloat(item.leaveCount);
      
      // If Monthly Pro-rata, calculate how many months have passed since policy start
      if (item.cappingType === 'Monthly') {
        const start = new Date(policy.start_date);
        const now = new Date();
        const diffMonths = (now.getFullYear() - start.getFullYear()) * 12 + (now.getMonth() - start.getMonth());
        const earnedPerMonth = parseFloat(item.cappingCount || 0);
        
        // Entitlement = Months passed * Earned per month (capped at total leaveCount)
        allocated = Math.min(allocated, diffMonths * earnedPerMonth);
      }

      const used = takenMap[item.leaveType] || 0;
      return {
        leaveType: item.leaveType,
        totalAllocated: parseFloat(item.leaveCount), // Max for the year
        currentlyEarned: allocated, // What they have earned till now
        used: used,
        available: Math.max(0, allocated - used),
        strategy: item.cappingType
      };
    });

    return balance;
  }
}

module.exports = LeaveRequestModel;
