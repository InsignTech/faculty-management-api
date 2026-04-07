const pool = require('../config/db');

class AttendanceModel {
    // Process raw logs for a specific date
    static async processLogs(date) {
        const [rows] = await pool.execute('CALL sp_process_attendance_logs(?)', [date]);
        return rows[0][0];
    }

    // Get attendance history for an employee
    static async getEmployeeAttendance(employeeId, month, year) {
        const [rows] = await pool.execute('CALL sp_get_employee_attendance(?, ?, ?)', [employeeId, month, year]);
        return rows[0];
    }

    // Get monthly attendance summary (late count, deductions, etc.)
    static async getAttendanceSummary(employeeId, month, year) {
        const [rows] = await pool.execute('CALL sp_get_attendance_summary(?, ?, ?)', [employeeId, month, year]);
        return rows[0][0];
    }

    // Request an adjustment (Regularization / On-Duty)
    static async requestAdjustment(data) {
        const { employee_id, type, date, punch_time, remarks, attachment_path } = data;
        const [rows] = await pool.execute(
            'CALL sp_request_attendance_adjustment(?, ?, ?, ?, ?, ?)',
            [employee_id, type, date, punch_time, remarks, attachment_path || null]
        );
        return rows[0][0];
    }

    // Approve an adjustment and trigger deduction recalculation
    static async approveAdjustment(adjustmentId, approverId, remarks) {
        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            // 1. Get the adjustment record
            const [adjRows] = await conn.execute(
                'SELECT * FROM attendance_adjustments WHERE adjustment_id = ?', [adjustmentId]
            );
            if (!adjRows.length) throw new Error('Adjustment not found');

            const adj = adjRows[0];

            // 2. Update adjustment status
            await conn.execute(
                `UPDATE attendance_adjustments 
                 SET status = 'Approved', approved_by_id = ?, approved_on = NOW(), remarks = CONCAT(COALESCE(remarks, ''), ' | Approval note: ', ?)
                 WHERE adjustment_id = ?`,
                [approverId, remarks || '', adjustmentId]
            );

            // 3. If this is a Regularization, trigger the deduction recalculation
            if (adj.type === 'Regularization') {
                await conn.execute('CALL sp_handle_regularization_approval(?, ?)', [adj.employee_id, adj.date]);
            }

            await conn.commit();
            return { success: true, message: 'Adjustment approved and deductions recalculated.' };
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }

    // Reject an adjustment
    static async rejectAdjustment(adjustmentId, approverId, remarks) {
        const [rows] = await pool.execute(
            `UPDATE attendance_adjustments 
             SET status = 'Rejected', approved_by_id = ?, approved_on = NOW(), remarks = ?
             WHERE adjustment_id = ?`,
            [approverId, remarks || '', adjustmentId]
        );
        return { affected_rows: rows.affectedRows };
    }

    // Get adjustment history for an employee
    static async getEmployeeAdjustments(employeeId) {
        const [rows] = await pool.execute('CALL sp_get_employee_adjustments(?)', [employeeId]);
        return rows[0];
    }

    // Admin: Get all pending adjustments
    static async getPendingAdjustments() {
        const [rows] = await pool.query(`
            SELECT aj.*, e.employee_name, e.employee_code 
            FROM attendance_adjustments aj 
            JOIN employee e ON aj.employee_id = e.employee_id 
            WHERE aj.status = 'Pending' 
            ORDER BY aj.requested_on ASC
        `);
        return rows;
    }

    // --- Machine Log Sync Methods ---

    // Start a sync log entry
    static async startSyncLog(totalRecords, payloadPreview) {
        const [result] = await pool.execute(
            'INSERT INTO attendance_sync_logs (start_time, total_records, payload_preview, status) VALUES (NOW(), ?, ?, ?)',
            [totalRecords, payloadPreview, 'Success']
        );
        return result.insertId;
    }

    // End a sync log entry
    static async endSyncLog(syncId, status, errorMessage = null) {
        await pool.execute(
            'UPDATE attendance_sync_logs SET end_time = NOW(), status = ?, error_message = ? WHERE sync_id = ?',
            [status, errorMessage, syncId]
        );
    }

    // Bulk insert machine logs
    static async insertMachineLogs(logs) {
        if (!logs || logs.length === 0) return 0;

        // Prepare bulk insert values
        // Expecting logs to be [{ employee_id: 123, punch_time: '2024-04-04 09:00:00' }, ...]
        const values = logs.map(log => [log.employee_id, log.punch_time]);
        
        const query = 'INSERT IGNORE INTO attendance_detail_log (employee_id, punch_time) VALUES ?';
        const [result] = await pool.query(query, [values]);
        
        return result.affectedRows;
    }
}

module.exports = AttendanceModel;
