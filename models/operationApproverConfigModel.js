const pool = require('../config/db');

class OperationApproverConfigModel {
    static async getConfig(requestType) {
        const query = `
            SELECT oac.*,
                   a1.employee_name AS approver_1_name,
                   a2.employee_name AS approver_2_name
            FROM operation_approver_configs oac
            LEFT JOIN employee a1 ON oac.approver_1_id = a1.employee_id
            LEFT JOIN employee a2 ON oac.approver_2_id = a2.employee_id
            WHERE oac.request_type = ?
        `;
        const [rows] = await pool.execute(query, [requestType.toUpperCase()]);
        return rows[0] || null;
    }

    static async getAllConfigs() {
        const query = `
            SELECT oac.*,
                   a1.employee_name AS approver_1_name,
                   a2.employee_name AS approver_2_name
            FROM operation_approver_configs oac
            LEFT JOIN employee a1 ON oac.approver_1_id = a1.employee_id
            LEFT JOIN employee a2 ON oac.approver_2_id = a2.employee_id
        `;
        const [rows] = await pool.execute(query);
        return rows;
    }

    static async saveConfig(requestType, approver1Id, approver2Id) {
        const query = `
            INSERT INTO operation_approver_configs (request_type, approver_1_id, approver_2_id)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE
                approver_1_id = VALUES(approver_1_id),
                approver_2_id = VALUES(approver_2_id)
        `;
        const [result] = await pool.execute(query, [
            requestType.toUpperCase(),
            approver1Id,
            approver2Id || null
        ]);
        return result;
    }

    static async deleteConfig(requestType) {
        const query = `DELETE FROM operation_approver_configs WHERE request_type = ?`;
        const [result] = await pool.execute(query, [requestType.toUpperCase()]);
        return result;
    }

    static async checkApproverAccess(employeeId) {
        const query = `
            SELECT COUNT(*) AS count 
            FROM operation_approver_configs 
            WHERE approver_1_id = ? OR approver_2_id = ?
        `;
        const [rows] = await pool.execute(query, [employeeId, employeeId]);
        return rows[0].count > 0;
    }
}

module.exports = OperationApproverConfigModel;
