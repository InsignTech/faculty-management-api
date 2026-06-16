const pool = require('../config/db');
const LeavePolicyModel = require('./leavePolicyModel');

class LeaveRequestModel {
  static async getAll(filters = {}) {
    let sql = `
      SELECT lr.*, e.employee_name, e.employee_code as emp_code,
             a1.employee_name AS approver_1_name,
             a2.employee_name AS approver_2_name,
             sub.employee_name AS substitute_name
      FROM leave_requests lr
      JOIN employee e ON lr.employee_id = e.employee_id
      LEFT JOIN employee a1 ON a1.employee_id = lr.approver_1_id
      LEFT JOIN employee a2 ON a2.employee_id = lr.approver_2_id
      LEFT JOIN employee sub ON sub.employee_id = lr.substitute_employee_id
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
      SELECT lr.*, e.employee_name, e.employee_code as emp_code,
             a1.employee_name AS approver_1_name,
             a2.employee_name AS approver_2_name,
             sub.employee_name AS substitute_name
      FROM leave_requests lr
      JOIN employee e ON lr.employee_id = e.employee_id
      LEFT JOIN employee a1 ON a1.employee_id = lr.approver_1_id
      LEFT JOIN employee a2 ON a2.employee_id = lr.approver_2_id
      LEFT JOIN employee sub ON sub.employee_id = lr.substitute_employee_id
      WHERE e.reporting_manager_id = ?
         OR lr.approver_1_id = ?
         OR lr.approver_2_id = ?
      ORDER BY lr.applied_on DESC
    `;
    const [rows] = await pool.execute(sql, [superiorId, superiorId, superiorId]);
    return rows;
  }

  static create = async (data) => {
    const { employee_id, leave_type, start_date, end_date, leave_half_type, reason, attachment_path, total_days, substitute_employee_id } = data;
    
    const halfType = leave_half_type || 'FullDay';
    const requestedDays = halfType !== 'FullDay' ? 0.5 : (total_days || 0);

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // 1. Balance Validation
      const [balanceRows] = await conn.execute(
        `SELECT leave_type, balance_leave
         FROM employee_leaves 
         WHERE emp_id = ? AND month_year = ?`,
        [employee_id, `${String(new Date(start_date).getMonth() + 1).padStart(2, '0')}-${new Date(start_date).getFullYear()}`]
      );
      
      const leaveBalance = balanceRows.find(b => b.leave_type === leave_type);
      if (leaveBalance && parseFloat(leaveBalance.balance_leave) < requestedDays) {
        throw new Error(`Insufficient balance for ${leave_type}. Available: ${leaveBalance.balance_leave}, Requested: ${requestedDays}`);
      }

      // 2. Overlap Validation
      const [overlaps] = await conn.execute(
        `SELECT leave_half_type FROM leave_requests 
         WHERE employee_id = ? AND status IN ('Pending', 'Approved')
           AND (? <= end_date AND ? >= start_date)`,
        [employee_id, start_date, end_date]
      );

      if (overlaps.length > 0) {
        const isConflict = overlaps.some(existing => {
          if (existing.leave_half_type === 'FullDay') return true;
          if (halfType === 'FullDay') return true;
          if (existing.leave_half_type === halfType) return true;
          return false;
        });
        if (isConflict) throw new Error('Leave request overlaps with an existing leave.');
      }

      // Check against approved adjustments in attendance_daily
      const [adjOverlaps] = await conn.execute(
        `SELECT date, regularization_shift_type, onduty_shift_type 
         FROM attendance_daily 
         WHERE employee_id = ? 
           AND (date BETWEEN ? AND ?)
           AND (regularization_shift_type IS NOT NULL OR onduty_shift_type IS NOT NULL)`,
        [employee_id, start_date, end_date]
      );

      if (adjOverlaps.length > 0) {
        const isAdjConflict = adjOverlaps.some(adj => {
          const adjShift = adj.regularization_shift_type || adj.onduty_shift_type;
          if (adjShift === 'FullDay') return true;
          if (halfType === 'FullDay') return true;
          if (adjShift === halfType) return true;
          return false;
        });
        if (isAdjConflict) throw new Error('Leave request overlaps with an approved regularization or on-duty shift.');
      }

      // Resolve approver config from employee_approver_configs
      const [configRows] = await conn.execute(
        `SELECT
            COALESCE(eac.approver_1_id, e.reporting_manager_id,
                (SELECT e2.employee_id FROM employee e2
                 JOIN app_role r2 ON e2.role_id = r2.role_id
                 WHERE r2.role IN ('Principal','principal') AND e2.active = 1 LIMIT 1)
            ) AS approver_1_id,
            eac.approver_2_id
         FROM employee e
         LEFT JOIN employee_approver_configs eac
             ON eac.employee_id = e.employee_id AND eac.request_type = 'LEAVE'
         WHERE e.employee_id = ?`,
        [employee_id]
      );

      const approver1 = configRows[0]?.approver_1_id || null;
      const approver2 = configRows[0]?.approver_2_id || null;

      // 3. Call SP to apply leave
      const [rows] = await conn.execute(
        'CALL sp_apply_leave(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          employee_id,
          leave_type,
          start_date,
          end_date,
          requestedDays,
          reason,
          attachment_path || null,
          substitute_employee_id || null,
          approver1,
          approver2
        ]
      );
      
      const result = rows[0][0];

      // 4. Correct total_days if necessary
      if (result && result.leave_request_id && (!result.total_days || result.total_days == 0)) {
         if (halfType !== 'FullDay') {
            await conn.execute('UPDATE leave_requests SET total_days = 0.5 WHERE leave_request_id = ?', [result.leave_request_id]);
         } else if (total_days > 0) {
            await conn.execute('UPDATE leave_requests SET total_days = ? WHERE leave_request_id = ?', [total_days, result.leave_request_id]);
         }
      }

      await conn.commit();
      return result;
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
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
  /**
   * CALCULATE LEAVE BALANCE
   * Now fetches from the employee_leaves table which is maintained by the accrual job and approval/cancellation SPs.
   */
  static async getLeaveBalance(employeeId, date = new Date()) {
    const d = new Date(date);
    const monthYear = `${String(d.getMonth() + 1).padStart(2, '0')}-${d.getFullYear()}`;

    // 1. Get the base balance from the employee_leaves table (only updated on approval/accrual)
    const [rows] = await pool.execute(
      `SELECT leave_type, opening_leave, credited_count, leaves_taken, total_leaves, balance_leave
       FROM employee_leaves 
       WHERE emp_id = ? AND month_year = ?`,
      [employeeId, monthYear]
    );

    // 2. Get any pending leave requests to reflect them in "Available" and "Used" immediately
    const [pendingRows] = await pool.execute(
      `SELECT leave_type, COALESCE(SUM(total_days), 0) as pending_days
       FROM leave_requests
       WHERE employee_id = ? AND status = 'Pending'
       GROUP BY leave_type`,
      [employeeId]
    );

    const pendingMap = {};
    pendingRows.forEach(p => {
      pendingMap[p.leave_type] = parseFloat(p.pending_days);
    });

    if (rows.length === 0) {
        // Fallback or initialization if no records exist yet for this month
        const policy = await LeavePolicyModel.getEffectivePolicy(employeeId, date);
        if (!policy) return [];
        return policy.policy_value.map(item => {
            const pendingVal = pendingMap[item.leaveType] || 0;
            const totalAlloc = parseFloat(item.leaveCount);
            return {
                leaveType: item.leaveType,
                totalAllocated: totalAlloc,
                opening: 0,
                credited: 0,
                used: pendingVal,
                available: totalAlloc - pendingVal,
                pending: pendingVal,
                strategy: item.creditFrequency || item.cappingType
            };
        });
    }

    return rows.map(row => {
      const pendingVal = pendingMap[row.leave_type] || 0;
      const baseUsed = parseFloat(row.leaves_taken);
      const baseAvailable = parseFloat(row.balance_leave);

      return {
        leaveType: row.leave_type,
        opening: parseFloat(row.opening_leave),
        credited: parseFloat(row.credited_count),
        used: baseUsed + pendingVal, // Include pending in used
        total: parseFloat(row.total_leaves),
        available: Math.max(0, baseAvailable - pendingVal), // Subtract pending from available
        currentlyEarned: parseFloat(row.total_leaves), 
        totalAllocated: parseFloat(row.total_leaves), 
        carryForward: parseFloat(row.opening_leave),
        pending: pendingVal, // Send pending separately for UI highlighting
        strategy: 'Table-Based'
      };
    });
  }

  static async superAdminCreateLeave(data, superAdminEmployeeId) {
    const { employee_id, leave_type, start_date, end_date, leave_half_type, reason, attachment_path, total_days, check_balance } = data;
    
    const halfType = leave_half_type || 'FullDay';
    const requestedDays = halfType !== 'FullDay' ? 0.5 : (total_days || 0);

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      if (check_balance) {
        const balances = await LeaveRequestModel.getLeaveBalance(employee_id, new Date(start_date));
        const leaveBalance = balances.find(b => b.leaveType === leave_type);
        if (!leaveBalance) {
          throw new Error(`Employee does not have leave type "${leave_type}" in their active policy.`);
        }
        if (leaveBalance.available < requestedDays) {
          throw new Error(`Insufficient balance for "${leave_type}". Available: ${leaveBalance.available}, Requested: ${requestedDays}`);
        }
      }

      // Bypassing balance check completely!
      const [rows] = await conn.execute(
        'CALL sp_apply_leave(?, ?, ?, ?, ?, ?, ?)',
        [employee_id, leave_type, start_date, end_date, halfType, reason, attachment_path || null]
      );
      
      const result = rows[0][0];

      if (!result || !result.leave_request_id) {
        throw new Error('Failed to create leave request via database stored procedure.');
      }

      const leaveRequestId = result.leave_request_id;

      // Correct total_days if necessary
      if (result && leaveRequestId && (!result.total_days || result.total_days == 0)) {
         if (halfType !== 'FullDay') {
            await conn.execute('UPDATE leave_requests SET total_days = 0.5 WHERE leave_request_id = ?', [leaveRequestId]);
         } else if (total_days > 0) {
            await conn.execute('UPDATE leave_requests SET total_days = ? WHERE leave_request_id = ?', [total_days, leaveRequestId]);
         }
      }

      await conn.commit();

      // Immediately approve it!
      await conn.execute(
        'CALL sp_approve_leave(?, ?, ?, ?)',
        [
          leaveRequestId,
          superAdminEmployeeId,
          'Approved',
          'Super Admin Direct Bypass Approval'
        ]
      );

      return { success: true, leave_request_id: leaveRequestId };
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  static async getApprovedWithSubstitutes(filters = {}, limit = 10, offset = 0) {
    let sql = `
      SELECT lr.*, e.employee_name, e.employee_code as emp_code,
             sub.employee_name AS substitute_name, sub.employee_code AS substitute_code
      FROM leave_requests lr
      JOIN employee e ON lr.employee_id = e.employee_id
      LEFT JOIN employee sub ON sub.employee_id = lr.substitute_employee_id
      WHERE lr.status = 'Approved'
        AND lr.substitute_employee_id IS NOT NULL
        AND lr.substitute_employee_id > 0
    `;
    const params = [];

    if (filters.date) {
      sql += ' AND ? BETWEEN lr.start_date AND lr.end_date';
      params.push(filters.date);
    }

    sql += ' ORDER BY lr.applied_on DESC';

    // Get total count for pagination
    let countSql = `SELECT COUNT(*) as total FROM (${sql}) as temp`;
    const [countRows] = await pool.execute(countSql, params);
    const total = countRows[0].total;

    sql += ' LIMIT ? OFFSET ?';
    params.push(limit.toString(), offset.toString());

    const [rows] = await pool.execute(sql, params);
    return { rows, total };
  }
}

module.exports = LeaveRequestModel;

