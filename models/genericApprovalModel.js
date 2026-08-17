const pool = require('../config/db');

class GenericApprovalModel {
    static async createRequest(data) {
        const query = `
            INSERT INTO generic_approvals 
            (request_type, entity_id, action_type, original_data, requested_data, requester_id, approver_1_id, approver_2_id, current_level, remarks)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;
        const [result] = await pool.execute(query, [
            data.request_type.toUpperCase(),
            data.entity_id || null,
            data.action_type.toUpperCase(),
            data.original_data ? JSON.stringify(data.original_data) : null,
            data.requested_data ? JSON.stringify(data.requested_data) : null,
            data.requester_id,
            data.approver_1_id,
            data.approver_2_id || null,
            data.current_level || 1,
            data.remarks || null
        ]);
        return result.insertId;
    }

    static async getById(id) {
        const query = `
            SELECT ga.*,
                   req.employee_name AS requester_name,
                   a1.employee_name AS approver_1_name,
                   a2.employee_name AS approver_2_name,
                   act.employee_name AS actioned_by_name
            FROM generic_approvals ga
            LEFT JOIN employee req ON ga.requester_id = req.employee_id
            LEFT JOIN employee a1 ON ga.approver_1_id = a1.employee_id
            LEFT JOIN employee a2 ON ga.approver_2_id = a2.employee_id
            LEFT JOIN employee act ON ga.actioned_by_id = act.employee_id
            WHERE ga.id = ?
        `;
        const [rows] = await pool.execute(query, [id]);
        return rows[0] || null;
    }

    static async getPendingForApprover(approverId) {
        const query = `
            SELECT ga.*,
                   req.employee_name AS requester_name
            FROM generic_approvals ga
            LEFT JOIN employee req ON ga.requester_id = req.employee_id
            WHERE ga.status = 'Pending'
              AND (
                (ga.current_level = 1 AND ga.approver_1_id = ?)
                OR (ga.current_level = 2 AND ga.approver_2_id = ?)
              )
            ORDER BY ga.requested_on DESC
        `;
        const [rows] = await pool.execute(query, [approverId, approverId]);
        return rows;
    }

    static async getApprovalsHistory(employeeId) {
        const query = `
            SELECT ga.*,
                   req.employee_name AS requester_name
            FROM generic_approvals ga
            LEFT JOIN employee req ON ga.requester_id = req.employee_id
            WHERE ga.requester_id = ? OR ga.approver_1_id = ? OR ga.approver_2_id = ?
            ORDER BY ga.requested_on DESC
        `;
        const [rows] = await pool.execute(query, [employeeId, employeeId, employeeId]);
        return rows;
    }

    static async updateLevel(id, nextLevel) {
        const query = `
            UPDATE generic_approvals
            SET current_level = ?
            WHERE id = ?
        `;
        await pool.execute(query, [nextLevel, id]);
    }

    static async actionRequest(id, status, remarks, actionedById) {
        const query = `
            UPDATE generic_approvals
            SET status = ?,
                remarks = ?,
                actioned_by_id = ?,
                actioned_on = NOW()
            WHERE id = ?
        `;
        await pool.execute(query, [status, remarks, actionedById, id]);
    }
}

module.exports = GenericApprovalModel;
