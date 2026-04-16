const pool = require('../config/db');

class LeaveModel {
    /**
     * Get leave balance for an employee (current year)
     */
    static async getBalance(employeeId, year) {
        const [rows] = await pool.execute(
            'CALL sp_get_leave_balance(?, ?)',
            [employeeId, year || new Date().getFullYear()]
        );
        return rows[0];
    }

    /**
     * Get leave types available for an employee based on their active policy
     */
    static async getAvailableTypes(employeeId) {
        const [rows] = await pool.execute(
            'CALL sp_get_leave_types_by_policy(?)',
            [employeeId]
        );
        return rows[0];
    }

    /**
     * Apply for a new leave
     */
    static async apply(data) {
        const { employee_id, leave_type, start_date, end_date, total_days, reason, attachment_path } = data;
        const [rows] = await pool.execute(
            'CALL sp_apply_leave(?, ?, ?, ?, ?, ?, ?)',
            [employee_id, leave_type, start_date, end_date, total_days, reason, attachment_path || null]
        );
        return rows[0][0];
    }

    /**
     * Get employee's own requests
     */
    static async getMyRequests(employeeId) {
        const [rows] = await pool.execute(
            'CALL sp_get_employee_leave_requests(?)',
            [employeeId]
        );
        return rows[0];
    }

    /**
     * Get subordinate requests for approval
     */
    static async getApprovals(managerId, status) {
        const [rows] = await pool.execute(
            'CALL sp_get_subordinate_leave_requests(?, ?)',
            [managerId, status || 'Pending']
        );
        return rows[0];
    }

    /**
     * Approve or Reject a leave request
     */
    static async action(requestId, status, approverId, remarks) {
        const [rows] = await pool.execute(
            'CALL sp_action_leave_request(?, ?, ?, ?)',
            [requestId, status, approverId, remarks || null]
        );
        return rows[0][0];
    }

    /**
     * Delete a pending leave request (Ownership check included)
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
