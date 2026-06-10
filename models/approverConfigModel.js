const pool = require('../config/db');

class ApproverConfigModel {
    /**
     * Get approver config for an employee+type.
     * Falls back to reporting manager, then Principal.
     */
    static async getConfig(employeeId, requestType) {
        const [rows] = await pool.execute(
            'CALL sp_get_approver_config(?, ?)',
            [employeeId, requestType]
        );
        return rows[0][0] || null;
    }

    /**
     * Get all configs for an employee (all 3 types).
     */
    static async getAllConfigs(employeeId) {
        const types = ['LEAVE', 'REGULARISATION', 'ONDUTY'];
        const results = {};
        for (const type of types) {
            results[type] = await this.getConfig(employeeId, type);
        }
        return results;
    }

    /**
     * Save/update approver config for an employee+type.
     */
    static async saveConfig(employeeId, requestType, approver1Id, approver2Id) {
        const [rows] = await pool.execute(
            'CALL sp_save_approver_config(?, ?, ?, ?)',
            [employeeId, requestType, approver1Id, approver2Id || null]
        );
        return rows[0][0];
    }

    /**
     * Check if a substitute employee is available for the given date range.
     * Returns conflicting leave requests if any.
     */
    static async checkSubstituteAvailability(substituteId, startDate, endDate) {
        const [rows] = await pool.execute(
            'CALL sp_check_substitute_availability(?, ?, ?)',
            [substituteId, startDate, endDate]
        );
        return rows[0]; // array of conflicting leave requests
    }

    /**
     * When an employee is deactivated, replace them as approver with Principal.
     * Called during employee update when active = 0.
     */
    static async reassignToPrincipal(deactivatedEmployeeId) {
        const [principalRows] = await pool.execute(
            `SELECT e.employee_id FROM employee e
             JOIN app_role r ON e.role_id = r.role_id
             WHERE r.role IN ('Principal','principal') AND e.active = 1
             LIMIT 1`
        );

        if (!principalRows.length) return { reassigned: 0 };

        const principalId = principalRows[0].employee_id;

        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            // 1. Update master approver configs
            await conn.execute(
                `UPDATE employee_approver_configs SET approver_1_id = ?
                 WHERE approver_1_id = ?`,
                [principalId, deactivatedEmployeeId]
            );
            await conn.execute(
                `UPDATE employee_approver_configs SET approver_2_id = ?
                 WHERE approver_2_id = ?`,
                [principalId, deactivatedEmployeeId]
            );

            // 2. Update active pending leave requests
            await conn.execute(
                `UPDATE leave_requests SET approver_1_id = ?
                 WHERE approver_1_id = ? AND status = 'Pending' AND current_level = 1`,
                [principalId, deactivatedEmployeeId]
            );
            await conn.execute(
                `UPDATE leave_requests SET approver_2_id = ?
                 WHERE approver_2_id = ? AND status = 'Pending' AND current_level = 2`,
                [principalId, deactivatedEmployeeId]
            );

            // 3. Update active pending regularization requests
            await conn.execute(
                `UPDATE attendance_regularization SET approver_1_id = ?
                 WHERE approver_1_id = ? AND status = 'Pending' AND current_level = 1`,
                [principalId, deactivatedEmployeeId]
            );
            await conn.execute(
                `UPDATE attendance_regularization SET approver_2_id = ?
                 WHERE approver_2_id = ? AND status = 'Pending' AND current_level = 2`,
                [principalId, deactivatedEmployeeId]
            );

            await conn.commit();
            return { reassigned: true, principal_id: principalId };
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }
}

module.exports = ApproverConfigModel;
