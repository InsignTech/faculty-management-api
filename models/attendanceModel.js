const pool = require('../config/db');
const SettingsModel = require('./settingsModel');

class AttendanceModel {
    // Process raw logs for a specific date
    static async processLogs(date) {
        const [rows] = await pool.execute('CALL sp_process_attendance(?)', [date]);
        return rows[0][0];
    }

    // Process raw logs for all missing dates up to today
    static async processMissedLogs() {
        const [rows] = await pool.query("SELECT MAX(date) as latest_date FROM attendance_daily");
        let latestDate = rows[0].latest_date;

        let startDate;
        if (!latestDate) {
            const [minLog] = await pool.query("SELECT DATE(MIN(punch_time)) as min_date FROM attendance_detail_log");
            if (!minLog[0].min_date) {
                return { total_processed: 0, days_processed: 0 };
            }
            startDate = new Date(minLog[0].min_date);
        } else {
            startDate = new Date(latestDate);
            startDate.setDate(startDate.getDate() + 1);
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);
        startDate.setHours(0, 0, 0, 0);

        let currentDate = startDate;
        let totalProcessed = 0;
        let daysProcessed = 0;

        while (currentDate <= today) {
            const year = currentDate.getFullYear();
            const month = String(currentDate.getMonth() + 1).padStart(2, '0');
            const day = String(currentDate.getDate()).padStart(2, '0');
            const localISOTime = `${year}-${month}-${day}`;

            const [resultRows] = await pool.execute('CALL sp_process_attendance(?)', [localISOTime]);
            const rowsProcessed = resultRows[0][0]?.processed_rows || 0;

            totalProcessed += rowsProcessed;
            daysProcessed++;

            currentDate.setDate(currentDate.getDate() + 1);
        }

        return { total_processed: totalProcessed, days_processed: daysProcessed };
    }

    // Get attendance history for an employee
    static async getEmployeeAttendance(employeeId, month, year) {
        const [rows] = await pool.execute('CALL sp_get_employee_attendance(?, ?, ?)', [employeeId, month, year]);
        return rows[0];
    }

    // Get attendance summary (late count, deductions, etc.)
    static async getAttendanceSummary(employeeId, month, year) {
        const [rows] = await pool.execute('CALL sp_get_attendance_summary(?, ?, ?)', [employeeId, month, year]);
        return rows[0][0];
    }

    // Get irregular attendance days (with deductions) for regularization
    static async getIrregularAttendance(employeeId, month, year) {
        console.log(employeeId, month, year)
        const [rows] = await pool.execute('CALL sp_get_irregular_attendance(?, ?, ?)', [employeeId, month, year]);
        console.log(rows[0])
        return rows[0];
    }

    // Request an adjustment (Regularization / On-Duty)
    static async requestAdjustment(data) {
        const { employee_id, type, date, from_date, to_date, punch_time, remarks, attachment_path } = data;

        // Verify employee is active
        const [empRows] = await pool.query('SELECT active FROM employee WHERE employee_id = ?', [employee_id]);
        if (!empRows.length || empRows[0].active === 0) {
            throw new Error('Adjustment requests can only be submitted for active employees.');
        }

        // Handle Date Range for On-Duty
        if (type === 'OnDuty' && from_date && to_date && from_date !== to_date) {
            const start = new Date(from_date);
            const end = new Date(to_date);
            const dates = [];

            // Loop through dates
            let current = new Date(start);
            while (current <= end) {
                dates.push(current.toISOString().split('T')[0]);
                current.setDate(current.getDate() + 1);
            }

            const conn = await pool.getConnection();
            try {
                await conn.beginTransaction();

                for (const d of dates) {
                    // 1. Duplicate Check
                    const [duplicates] = await conn.query(
                        `SELECT status FROM attendance_adjustments 
                         WHERE employee_id = ? AND date = ? AND type = ? AND status IN ('Pending', 'Approved')`,
                        [employee_id, d, type]
                    );

                    if (duplicates.length > 0) {
                        throw new Error(`An On-Duty request already exists for ${d}.`);
                    }

                    // 2. Presence Validation
                    const [presence] = await conn.query(
                        `SELECT 1 FROM attendance_daily WHERE employee_id = ? AND date = ? AND status = 'Present' LIMIT 1`,
                        [employee_id, d]
                    );

                    if (presence.length > 0) {
                        throw new Error(`You are already marked as Present on ${d}. You cannot request On-Duty for this date.`);
                    }

                    // 3. Insert
                    await conn.execute(
                        `INSERT INTO attendance_adjustments 
                        (employee_id, type, date, punch_time, remarks, attachment_path, status, requested_on) 
                        VALUES (?, ?, ?, ?, ?, ?, 'Pending', NOW())`,
                        [employee_id, type, d, punch_time, remarks, attachment_path || null]
                    );
                }

                await conn.commit();
                return { success: true, count: dates.length };
            } catch (err) {
                await conn.rollback();
                throw err;
            } finally {
                conn.release();
            }
        }

        // Single Date Logic (Regularization or single-day On-Duty)
        const targetDate = date || from_date;

        // 1. Duplicate Check
        const [duplicates] = await pool.query(
            `SELECT status FROM attendance_adjustments 
             WHERE employee_id = ? AND date = ? AND type = ? AND status IN ('Pending', 'Approved')`,
            [employee_id, targetDate, type]
        );

        if (duplicates.length > 0) {
            throw new Error(`A ${duplicates[0].status.toLowerCase()} ${type} request already exists for this date.`);
        }

        // 2. Validation for Regularization
        if (type === 'Regularization') {
            if (new Date(targetDate) > new Date()) {
                throw new Error('Regularization cannot be requested for future dates.');
            }

            const [attendanceRows] = await pool.query(
                `SELECT is_late, is_early_leaving, status, first_in_time, last_out_time 
                 FROM attendance_daily 
                 WHERE employee_id = ? AND date = ?`,
                [employee_id, targetDate]
            );

            if (attendanceRows.length > 0) {
                const day = attendanceRows[0];
                const isComplete = day.status === 'Present' && day.first_in_time && day.last_out_time && day.is_late === 0 && day.is_early_leaving === 0;
                if (isComplete) {
                    throw new Error('Attendance is already marked as complete and on-time for this date.');
                }
            }
        } else if (type === 'OnDuty') {
            // Presence validation for single day On-Duty
            const [presence] = await pool.query(
                `SELECT 1 FROM attendance_daily WHERE employee_id = ? AND date = ? AND status = 'Present' LIMIT 1`,
                [employee_id, targetDate]
            );

            if (presence.length > 0) {
                throw new Error(`You are already marked as Present on ${targetDate}. You cannot request On-Duty for this date.`);
            }
        }

        const [result] = await pool.execute(
            `INSERT INTO attendance_adjustments 
            (employee_id, type, date, punch_time, remarks, attachment_path, status, requested_on) 
            VALUES (?, ?, ?, ?, ?, ?, 'Pending', NOW())`,
            [employee_id, type, targetDate, punch_time, remarks, attachment_path || null]
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

                // Fetch dynamic regularization limit from settings
                let limit = 3;
                try {
                    const limitSetting = await SettingsModel.getSettingByKey('regularization_limit');
                    if (limitSetting && limitSetting.settings_value) {
                        limit = parseInt(limitSetting.settings_value);
                    }
                } catch (err) {
                    console.error('Error fetching regularization limit setting:', err);
                }

                const deduction = approvedCount < limit ? 0.00 : 0.50;

                await conn.execute(
                    `UPDATE attendance_daily 
                     SET is_regularized = 1, deduction_days = ?, status = 'Present', is_regularize_type = 'Regularization'
                     WHERE employee_id = ? AND date = ?`,
                    [deduction, adj.employee_id, adj.date]
                );
            } else if (adj.type === 'OnDuty') {
                // Update attendance_daily for On-Duty
                await conn.execute(
                    `UPDATE attendance_daily 
                     SET status = 'Present', first_in_time = '09:00:00', last_out_time = '17:00:00', 
                         is_regularized = 1, deduction_days = 0.00, is_regularize_type = 'OnDuty'
                     WHERE employee_id = ? AND date = ?`,
                    [adj.employee_id, adj.date]
                );
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

    // Get a specific adjustment by ID
    static async getEmployeeAdjustmentsById(id) {
        const [rows] = await pool.execute(
            `SELECT * FROM attendance_adjustments WHERE adjustment_id = ?`,
            [id]
        );
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

    // Manager/HOD: Get pending adjustments for all subordinates
    static async getPendingSubordinateAdjustments(managerId) {
        const query = `
            WITH RECURSIVE subordinates AS (
                SELECT employee_id
                FROM employee
                WHERE reporting_manager_id = ?
                UNION ALL
                SELECT e.employee_id
                FROM employee e
                INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
            )
            SELECT aj.*, e.employee_name, e.employee_code 
            FROM attendance_adjustments aj 
            JOIN employee e ON aj.employee_id = e.employee_id 
            WHERE aj.employee_id IN (SELECT employee_id FROM subordinates)
              AND aj.status = 'Pending'
            ORDER BY aj.requested_on ASC
        `;
        const [rows] = await pool.execute(query, [managerId]);
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

        const query = 'INSERT IGNORE INTO attendance_detail_log (employee_code, punch_time) VALUES ?';
        const [result] = await pool.query(query, [values]);

        return result.affectedRows;
    }
}

module.exports = AttendanceModel;
