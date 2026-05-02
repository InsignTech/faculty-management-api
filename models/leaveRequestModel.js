const pool = require('../config/db');

class LeaveRequestModel {
    static async getLeaveBalance(employeeId, year = new Date().getFullYear()) {
        const [rows] = await pool.execute('CALL sp_get_leave_balance(?, ?)', [employeeId, year]);
        return rows[0]; // SP returns the first result set
    }

    static async applyLeave(data) {
        const { employee_id, leave_type, start_date, end_date, total_days, reason, attachment_path } = data;

        // Verify employee is active
        const [empRows] = await pool.query('SELECT active FROM employee WHERE employee_id = ?', [employee_id]);
        if (!empRows.length || empRows[0].active === 0) {
            throw new Error('Leave requests can only be submitted for active employees.');
        }
        const [rows] = await pool.execute(
            'CALL sp_apply_leave(?, ?, ?, ?, ?, ?, ?)',
            [employee_id, leave_type, start_date, end_date, total_days, reason, attachment_path || null]
        );
        return rows[0][0];
    }

    static async getEmployeeLeaves(employeeId) {
        const [rows] = await pool.execute('CALL sp_get_employee_leave_requests(?)', [employeeId]);
        return rows[0];
    }
}

module.exports = LeaveRequestModel;
