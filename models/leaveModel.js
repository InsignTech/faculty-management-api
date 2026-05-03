const pool = require('../config/db');
const LeaveRequestModel = require('./leaveRequestModel');

class LeaveModel {
    /**
     * Get leave balance for an employee
     * Delegates to LeaveRequestModel which has the verified balance engine
     * (carry-forward, monthly accumulation, hierarchy).
     */
    static async getBalance(employeeId) {
        return LeaveRequestModel.getLeaveBalance(employeeId);
    }

    /**
     * Get leave types available for an employee based on their active policy.
     * Returns the leave type names from the effective merged policy.
     */
    static async getAvailableTypes(employeeId) {
        const balance = await LeaveRequestModel.getLeaveBalance(employeeId);
        // Return just the type names and available days for dropdown consumption
        return balance.map(b => ({
            leave_type: b.leaveType,
            available: b.available,
            strategy: b.strategy
        }));
    }

    /**
     * Apply for a new leave — uses the verified sp_apply_leave procedure.
     * NOTE: sp_apply_leave signature is:
     *   (employee_id, leave_type, start_date, end_date, half_type, reason, attachment)
     */
    static async apply(data) {
        const {
            employee_id,
            leave_type,
            start_date,
            end_date,
            leave_half_type,
            reason,
            attachment_path
        } = data;
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
        return rows[0][0];
    }

    /**
     * Get employee's own leave requests (direct SQL, no broken SP dependency).
     */
    static async getMyRequests(employeeId) {
        const [rows] = await pool.execute(
            `SELECT lr.*
             FROM leave_requests lr
             WHERE lr.employee_id = ?
             ORDER BY lr.applied_on DESC`,
            [employeeId]
        );
        return rows;
    }

    /**
     * Get subordinate requests for approval.
     * managerId = null → Admin view (all requests)
     * managerId = <id>  → Manager view (only their direct reports)
     */
    static async getApprovals(managerId, status) {
        let sql = `
            SELECT
                lr.*,
                e.employee_name,
                e.employee_code  AS emp_code,
                e.designation_id,
                d.departmentname AS department_name
            FROM leave_requests lr
            JOIN employee e ON lr.employee_id = e.employee_id
            LEFT JOIN department d ON e.department_id = d.department_id
            WHERE 1=1
        `;
        const params = [];

        if (managerId) {
            sql += ' AND e.reporting_manager_id = ?';
            params.push(managerId);
        }

        if (status && status !== 'All') {
            sql += ' AND lr.status = ?';
            params.push(status);
        }

        sql += ' ORDER BY lr.applied_on DESC';

        const [rows] = await pool.execute(sql, params);
        return rows;
    }

    /**
     * Approve or Reject a leave request.
     * Uses the verified sp_approve_leave which also syncs attendance_daily.
     */
    static async action(requestId, status, approverId, remarks) {
        if (!['Approved', 'Rejected'].includes(status)) {
            throw new Error('Invalid status: must be Approved or Rejected');
        }
        const [rows] = await pool.execute(
            'CALL sp_approve_leave(?, ?, ?, ?)',
            [requestId, approverId, status, remarks || null]
        );
        return rows[0][0];
    }

    /**
     * Delete a pending leave request (only the owner can delete, only if Pending).
     */
    static async delete(requestId, employeeId) {
        const [result] = await pool.execute(
            'DELETE FROM leave_requests WHERE leave_request_id = ? AND employee_id = ? AND status = "Pending"',
            [requestId, employeeId]
        );
        return result;
    }
}

module.exports = LeaveModel;
