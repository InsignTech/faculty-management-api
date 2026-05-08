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
            attachment_path,
            total_days
        } = data;

        const halfType = leave_half_type || 'FullDay';

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

        // Safety net for half-days
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
     * Cancel a leave request (Update status to Cancelled).
     * Owners can cancel Pending.
     * Admins/Managers can cancel Pending or Approved.
     */
    static async cancel(requestId, cancellerId, cancellerRole) {
        // Fetch request details
        const [rows] = await pool.execute(
            'SELECT status, employee_id FROM leave_requests WHERE leave_request_id = ?',
            [requestId]
        );

        if (rows.length === 0) return { affected_rows: 0, message: 'Request not found' };
        const request = rows[0];

        const isAdmin = cancellerRole && ['super_admin', 'admin', 'Admin', 'Principal', 'principal', 'HOD', 'Manager'].includes(cancellerRole);
        
        // Manager check
        const [managerCheck] = await pool.execute(
            'SELECT 1 FROM employee WHERE employee_id = ? AND reporting_manager_id = ?',
            [request.employee_id, cancellerId]
        );
        const isManager = managerCheck.length > 0;
        const isOwner = request.employee_id === cancellerId;

        if (!isOwner && !isAdmin && !isManager) {
            throw new Error('Not authorized to cancel this request');
        }

        // Owners only Pending, Admins/Managers Pending or Approved
        if (isOwner && !isAdmin && !isManager && request.status !== 'Pending') {
            throw new Error('You can only cancel your own pending requests');
        }

        if (request.status === 'Rejected' || request.status === 'Cancelled') {
            throw new Error(`Cannot cancel a request that is already ${request.status}`);
        }

        // If the leave was already approved, we need to reverse the attendance status
        if (request.status === 'Approved') {
            const AttendanceModel = require('./attendanceModel');
            // Fetch the dates again or use the request object if it has them
            const [leaveInfo] = await pool.execute(
                'SELECT start_date, end_date FROM leave_requests WHERE leave_request_id = ?',
                [requestId]
            );
            if (leaveInfo.length > 0) {
                await AttendanceModel.revertLeave(request.employee_id, leaveInfo[0].start_date, leaveInfo[0].end_date);
            }
        }

        const [result] = await pool.execute(
            'UPDATE leave_requests SET status = "Cancelled", approved_by_id = ? WHERE leave_request_id = ?',
            [cancellerId, requestId]
        );

        return { affected_rows: result.affectedRows };
    }
}

module.exports = LeaveModel;
