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

        // 1. Duplicate Check: Block if a request already exists for this date and type
        const [duplicates] = await pool.query(
            `SELECT status FROM attendance_adjustments 
             WHERE employee_id = ? AND date = ? AND type = ? AND status IN ('Pending', 'Approved')`,
            [employee_id, date, type]
        );

        if (duplicates.length > 0) {
            throw new Error(`A ${duplicates[0].status.toLowerCase()} ${type} request already exists for this date.`);
        }

        // 2. Validation for Regularization
        if (type === 'Regularization') {
            // A. Prevent future regularizations
            if (new Date(date) > new Date()) {
                throw new Error('Regularization cannot be requested for future dates. Please use On-Duty for planned external work.');
            }

            // B. Check if regularization is actually needed
            // Not needed if: Has both In and Out, both are Present, and neither is Late nor Early Leaving
            const [attendanceRows] = await pool.query(
                `SELECT type, is_late, is_early_leaving, status 
                 FROM attendance 
                 WHERE employee_id = ? AND date = ?`,
                [employee_id, date]
            );

            // Filter for 'Perfect' punches
            const perfectPunches = attendanceRows.filter(r => 
                r.status === 'Present' && r.is_late === 0 && r.is_early_leaving === 0
            );

            // If we have at least 2 perfect punches (In and Out), regularization is not needed
            if (perfectPunches.length >= 2) {
                throw new Error('Attendance is already marked as complete and on-time for this date. Regularization is not required.');
            }
        }

        const [result] = await pool.execute(
            `INSERT INTO attendance_adjustments 
            (employee_id, type, date, punch_time, remarks, attachment_path, status, requested_on) 
            VALUES (?, ?, ?, ?, ?, ?, 'Pending', NOW())`,
            [employee_id, type, date, punch_time, remarks, attachment_path || null]
        );
        
        return { adjustment_id: result.insertId };
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
            const v_month = new Date(adj.date).getMonth() + 1;
            const v_year = new Date(adj.date).getFullYear();

            // 2. Update status to Approved
            await conn.execute(
                `UPDATE attendance_adjustments 
                 SET status = 'Approved', approved_by_id = ?, approved_on = NOW(), 
                     remarks = CONCAT(COALESCE(remarks, ''), ' | Final Approval: ', ?)
                 WHERE adjustment_id = ?`,
                [approverId, remarks || '', adjustmentId]
            );

            // 3. Apply changes to attendance table based on type
            if (adj.type === 'Regularization') {
                // Count previous approved regularizations this month
                const [countRows] = await conn.execute(
                    `SELECT COUNT(*) as approved_count 
                     FROM attendance_adjustments 
                     WHERE employee_id = ? AND MONTH(date) = ? AND YEAR(date) = ? 
                     AND status = 'Approved' AND type = 'Regularization'
                     AND adjustment_id != ?`,
                    [adj.employee_id, v_month, v_year, adjustmentId]
                );
                
                const approvedCount = countRows[0].approved_count;
                const deduction = approvedCount < 3 ? 0.00 : 0.50;

                await conn.execute(
                    `UPDATE attendance 
                     SET is_regularized = 1, deduction_days = ?, status = 'Present'
                     WHERE employee_id = ? AND date = ?`,
                    [deduction, adj.employee_id, adj.date]
                );
            } else if (adj.type === 'OnDuty') {
                // Insert/Update standard logs for On-Duty
                const shifts = [
                    { type: 'PunchIn', time: '09:00:00' },
                    { type: 'PunchOut', time: '17:00:00' }
                ];

                for (const shift of shifts) {
                    await conn.execute(
                        `INSERT INTO attendance 
                         (employee_id, date, status, punch_type, type, shift_type, punch_time, is_regularized, deduction_days)
                         VALUES (?, ?, 'Present', 'Onduty', ?, 'Full Day', ?, 1, 0.00)
                         ON DUPLICATE KEY UPDATE 
                             status = 'Present', punch_type = 'Onduty', punch_time = ?, is_regularized = 1, deduction_days = 0.00`,
                        [adj.employee_id, adj.date, shift.type, shift.time, shift.time]
                    );
                }
            }

            await conn.commit();
            return { success: true, message: 'Adjustment approved.' };
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

    // Delete a pending adjustment
    static async deleteAdjustment(adjustmentId, employeeId) {
        const [rows] = await pool.execute(
            `DELETE FROM attendance_adjustments 
             WHERE adjustment_id = ? AND employee_id = ? AND status = 'Pending'`,
            [adjustmentId, employeeId]
        );
        return { affected_rows: rows.affectedRows };
    }

    // Get adjustment history for an employee with filters
    static async getEmployeeAdjustments(employeeId, month = null, year = null) {
        let query = `
            SELECT aj.*, e.employee_name as approver_name 
            FROM attendance_adjustments aj 
            LEFT JOIN employee e ON aj.approved_by_id = e.employee_id 
            WHERE aj.employee_id = ?
        `;
        const params = [employeeId];

        if (month) {
            query += " AND MONTH(aj.date) = ?";
            params.push(month);
        }
        if (year) {
            query += " AND YEAR(aj.date) = ?";
            params.push(year);
        }

        query += " ORDER BY aj.requested_on DESC";

        const [rows] = await pool.execute(query, params);
        return rows;
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
