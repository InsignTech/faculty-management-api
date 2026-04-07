const pool = require('../config/db');

class LeaveEncashmentModel {
    static async request(employeeId, leaveType, days) {
        const [rows] = await pool.execute('CALL sp_request_leave_encashment(?, ?, ?)', [employeeId, leaveType, days]);
        return rows[0][0];
    }

    static async getHistory(employeeId) {
        const [rows] = await pool.execute('CALL sp_get_leave_encashments(?)', [employeeId]);
        return rows[0];
    }

    static async getAllPending() {
        const [rows] = await pool.query(`
            SELECT le.*, e.employee_name, e.employee_code, e.employee_type
            FROM leave_encashments le
            JOIN employee e ON le.employee_id = e.employee_id
            WHERE le.status = 'Pending'
            ORDER BY le.requested_on ASC
        `);
        return rows;
    }
}

module.exports = LeaveEncashmentModel;
