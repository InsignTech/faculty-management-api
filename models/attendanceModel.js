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
        const [rows] = await pool.query('CALL sp_get_employee_attendance(?, ?, ?)', [employeeId, month, year]);
        return rows[0] || [];
    }

    // Get attendance summary (late count, deductions, etc.)
    static async getAttendanceSummary(employeeId, month, year) {
        const [rows] = await pool.query('CALL sp_get_attendance_summary(?, ?, ?)', [employeeId, month, year]);
        return (rows[0] && rows[0].length > 0) ? rows[0][0] : null;
    }

    // Get irregular attendance days (with deductions) for regularization
    static async getIrregularAttendance(employeeId, month, year) {
        const [rows] = await pool.query('CALL sp_get_irregular_attendance(?, ?, ?)', [employeeId, month, year]);
        return rows[0] || [];
    }

    // Request an adjustment (Regularization / On-Duty)
    static async requestAdjustment(data) {
        const { 
            employee_id, type, date, from_date, to_date, 
            requested_in_time, requested_out_time, 
            regularization_shift_type, 
            reason, attachment_path 
        } = data;

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
                        `SELECT status FROM attendance_regularization 
                         WHERE employee_id = ? AND date = ? AND request_type = ? AND status IN ('Pending', 'Approved')`,
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
                        `INSERT INTO attendance_regularization 
                        (employee_id, request_type, date, requested_in_time, requested_out_time, regularization_shift_type, reason, status, created_on) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending', NOW())`,
                        [employee_id, type, d, requested_in_time || null, requested_out_time || null, regularization_shift_type || 'FullDay', reason]
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

        // 1. Cross-Type Adjustment Check (Regularization or On-Duty)
        const [adjDuplicates] = await pool.query(
            `SELECT status, request_type, regularization_shift_type FROM attendance_regularization 
             WHERE employee_id = ? AND date = ? AND status IN ('Pending', 'Approved')`,
            [employee_id, targetDate]
        );

        const requestedShift = regularization_shift_type || 'FullDay';

        if (adjDuplicates.length > 0) {
            for (const dup of adjDuplicates) {
                if (dup.regularization_shift_type === 'FullDay' || requestedShift === 'FullDay' || dup.regularization_shift_type === requestedShift) {
                    throw new Error(`A ${dup.status.toLowerCase()} ${dup.request_type} request already exists for this date (${dup.regularization_shift_type}).`);
                }
            }
        }

        // 2. Overlapping Leave Check
        const shiftType = regularization_shift_type || 'FullDay';
        const [leaveOverlap] = await pool.query(
            `SELECT leave_half_type, status FROM leave_requests 
             WHERE employee_id = ? AND ? BETWEEN start_date AND end_date AND status IN ('Pending', 'Approved')`,
            [employee_id, targetDate]
        );

        if (leaveOverlap.length > 0) {
            const leave = leaveOverlap[0];
            if (leave.leave_half_type === 'FullDay' || shiftType === 'FullDay' || leave.leave_half_type === shiftType) {
                throw new Error(`Overlap Error: A ${leave.status.toLowerCase()} leave request exists for this period (${leave.leave_half_type}).`);
            }
        }

        // 3. Approved State Validation (Check attendance_daily)
        const [attendanceRows] = await pool.query(
            `SELECT status, first_in_time, last_out_time, is_late, is_early_leaving, 
                    leave_shift_type, regularization_shift_type, onduty_shift_type 
             FROM attendance_daily 
             WHERE employee_id = ? AND date = ?`,
            [employee_id, targetDate]
        );

        if (attendanceRows.length > 0) {
            const row = attendanceRows[0];
            
            // Validation for Regularization
            if (type === 'Regularization') {
                if (new Date(targetDate) > new Date()) {
                    throw new Error('Regularization cannot be requested for future dates.');
                }

                // Check if already completely regularized/covered in attendance_daily
                if (row.regularization_shift_type === 'FullDay' || 
                    (requestedShift !== 'FullDay' && row.regularization_shift_type === requestedShift)) {
                    throw new Error(`This ${requestedShift} shift is already regularized.`);
                }

                // Strict "Present" Check: If they are Present and not late/early, they don't need regularization
                // for the shift they are claiming. 
                if (row.status === 'Present' && row.first_in_time && row.last_out_time) {
                    if (requestedShift === 'FullDay' && row.is_late === 0 && row.is_early_leaving === 0) {
                        throw new Error('Attendance is already marked as complete and on-time for this date.');
                    }
                    if (requestedShift === 'FirstHalf' && row.is_late === 0) {
                        throw new Error('You were not late in the 1st half, regularization is not required.');
                    }
                    if (requestedShift === 'SecondHalf' && row.is_early_leaving === 0) {
                        throw new Error('You did not leave early in the 2nd half, regularization is not required.');
                    }
                }
            }

            // Cross-column overlap check (Approved states in attendance_daily)
            const activeStates = [
                { type: 'Leave', shift: row.leave_shift_type },
                { type: 'Regularization', shift: row.regularization_shift_type },
                { type: 'On-Duty', shift: row.onduty_shift_type }
            ];

            for (const state of activeStates) {
                if (state.shift) {
                    if (state.shift === 'FullDay' || requestedShift === 'FullDay' || state.shift === requestedShift) {
                        throw new Error(`Overlap Error: This shift is already covered by an approved ${state.type} (${state.shift}).`);
                    }
                }
            }
        }

        const [result] = await pool.execute(
            `INSERT INTO attendance_regularization 
            (employee_id, request_type, date, requested_in_time, requested_out_time, regularization_shift_type, reason, status, created_on) 
            VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending', NOW())`,
            [employee_id, type, targetDate, requested_in_time || null, requested_out_time || null, regularization_shift_type || 'FullDay', reason]
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
                'SELECT * FROM attendance_regularization WHERE id = ?', [adjustmentId]
            );
            if (!adjRows.length) throw new Error('Adjustment not found');

            const adj = adjRows[0];
            const v_month = new Date(adj.date).getMonth() + 1;
            const v_year = new Date(adj.date).getFullYear();

            // 2. Check for overlapping approved states in attendance_daily
            const [overlapCheck] = await conn.execute(
                `SELECT leave_shift_type, regularization_shift_type, onduty_shift_type FROM attendance_daily 
                 WHERE employee_id = ? AND date = ?`,
                [adj.employee_id, adj.date]
            );

            const requestedShift = adj.regularization_shift_type || 'FullDay';

            if (overlapCheck.length > 0) {
                const row = overlapCheck[0];
                const activeShifts = [
                    { type: 'Leave', shift: row.leave_shift_type },
                    { type: 'Regularization', shift: row.regularization_shift_type },
                    { type: 'On-Duty', shift: row.onduty_shift_type }
                ].filter(s => s.shift !== null);

                for (const s of activeShifts) {
                    if (s.shift === 'FullDay' || requestedShift === 'FullDay' || s.shift === requestedShift) {
                        throw new Error(`Approval Error: This shift is already covered by an approved ${s.type} (${s.shift}).`);
                    }
                }
            }

            // 3. Update request status
            await conn.execute(
                `UPDATE attendance_regularization 
                 SET status = 'Approved', approved_by = ?, approved_on = NOW(), 
                     reason = CONCAT(COALESCE(reason, ''), ' | Final Approval: ', ?)
                 WHERE id = ?`,
                [approverId, remarks || '', adjustmentId]
            );

            // 4. Fetch current attendance state for smart merge
            const [attendanceRows] = await conn.execute(
                `SELECT status, shift_type, leave_shift_type, regularization_shift_type, onduty_shift_type 
                 FROM attendance_daily WHERE employee_id = ? AND date = ?`,
                [adj.employee_id, adj.date]
            );
            const row = attendanceRows[0] || {};

            // 5. Apply changes to attendance table
            if (adj.request_type === 'Regularization') {
                // Limit check logic
                const [countRows] = await conn.execute(
                    `SELECT COUNT(*) as approved_count FROM attendance_regularization 
                     WHERE employee_id = ? AND MONTH(date) = ? AND YEAR(date) = ? 
                     AND status = 'Approved' AND request_type = 'Regularization' AND id != ?`,
                    [adj.employee_id, v_month, v_year, adjustmentId]
                );
                const approvedCount = countRows[0].approved_count;

                let limit = 3;
                try {
                    const limitSetting = await SettingsModel.getSettingByKey('regularization_limit');
                    if (limitSetting?.settings_value) limit = parseInt(limitSetting.settings_value);
                } catch (err) {
                    console.error('Limit fetch failed:', err);
                }

                let finalRegShift = requestedShift;
                // If already partially regularized, maybe promote to FullDay
                if (row.regularization_shift_type && row.regularization_shift_type !== 'FullDay' && row.regularization_shift_type !== requestedShift) {
                    finalRegShift = 'FullDay';
                }

                // Deduction calculation
                let deduction = (finalRegShift === 'FullDay') ? 0.00 : 0.50;
                
                const isFirstHalfCovered = (row.shift_type === 'FirstHalf' || row.shift_type === 'FullDay' || 
                    row.leave_shift_type === 'FirstHalf' || row.leave_shift_type === 'FullDay' ||
                    row.regularization_shift_type === 'FirstHalf' || row.onduty_shift_type === 'FirstHalf' || row.onduty_shift_type === 'FullDay');
                const isSecondHalfCovered = (row.shift_type === 'SecondHalf' || row.shift_type === 'FullDay' || 
                    row.leave_shift_type === 'SecondHalf' || row.leave_shift_type === 'FullDay' ||
                    row.regularization_shift_type === 'SecondHalf' || row.onduty_shift_type === 'SecondHalf' || row.onduty_shift_type === 'FullDay');

                if ((requestedShift === 'FirstHalf' && isSecondHalfCovered) || 
                    (requestedShift === 'SecondHalf' && isFirstHalfCovered) || (finalRegShift === 'FullDay')) {
                    deduction = 0.00;
                }
                if (approvedCount >= limit) deduction += 0.50;
                if (deduction > 1.0) deduction = 1.0;

                await conn.execute(
                    `UPDATE attendance_daily SET status = 'Present', regularization_shift_type = ?, deduction_days = ?
                     WHERE employee_id = ? AND date = ?`,
                    [finalRegShift, deduction, adj.employee_id, adj.date]
                );
            } else if (adj.request_type === 'OnDuty') {
                await conn.execute(
                    `UPDATE attendance_daily SET status = 'Present', onduty_shift_type = ?, deduction_days = 0.00,
                            first_in_time = '09:00:00', last_out_time = '17:00:00'
                     WHERE employee_id = ? AND date = ?`,
                    [requestedShift, adj.employee_id, adj.date]
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
            `UPDATE attendance_regularization 
             SET status = 'Rejected', approved_by = ?, approved_on = NOW(), reason = ?
             WHERE id = ?`,
            [approverId, remarks || '', adjustmentId]
        );
        return { affected_rows: rows.affectedRows };
    }

    // Delete a pending adjustment
    static async deleteAdjustment(adjustmentId, employeeId) {
        const [rows] = await pool.execute(
            `DELETE FROM attendance_regularization 
             WHERE id = ? AND employee_id = ? AND status = 'Pending'`,
            [adjustmentId, employeeId]
        );
        return { affected_rows: rows.affectedRows };
    }

    // Get adjustment history for an employee with filters
    static async getEmployeeAdjustments(employeeId, month = null, year = null) {
        let query = `
            SELECT aj.*, e.employee_name as approver_name 
            FROM attendance_regularization aj 
            LEFT JOIN employee e ON aj.approved_by = e.employee_id 
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

        query += " ORDER BY aj.created_on DESC";

        const [rows] = await pool.execute(query, params);
        return rows;
    }

    // Get a specific adjustment by ID
    static async getEmployeeAdjustmentsById(id) {
        const [rows] = await pool.execute(
            `SELECT * FROM attendance_regularization WHERE id = ?`,
            [id]
        );
        return rows;
    }

    // Admin: Get all pending adjustments
    static async getPendingAdjustments() {
        const [rows] = await pool.query(`
            SELECT aj.*, e.employee_name, e.employee_code 
            FROM attendance_regularization aj 
            JOIN employee e ON aj.employee_id = e.employee_id 
            WHERE aj.status = 'Pending' 
            ORDER BY aj.created_on ASC
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
            FROM attendance_regularization aj 
            JOIN employee e ON aj.employee_id = e.employee_id 
            WHERE aj.employee_id IN (SELECT employee_id FROM subordinates)
              AND aj.status = 'Pending'
            ORDER BY aj.created_on ASC
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

    /**
     * Revert attendance records from 'Leave' status back to 'Absent' 
     * and re-evaluate them if a leave is cancelled.
     */
    static async revertLeave(employeeId, startDate, endDate) {
        const start = new Date(startDate);
        const end = new Date(endDate);
        const dates = [];
        
        let current = new Date(start);
        // Reset to midnight to avoid hour-based comparison issues
        current.setHours(0, 0, 0, 0);
        const finalEnd = new Date(end);
        finalEnd.setHours(0, 0, 0, 0);

        while (current <= finalEnd) {
            const year = current.getFullYear();
            const month = String(current.getMonth() + 1).padStart(2, '0');
            const day = String(current.getDate()).padStart(2, '0');
            dates.push(`${year}-${month}-${day}`);
            
            current.setDate(current.getDate() + 1);
        }

        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();
            for (const d of dates) {
                // 1. Delete the 'Leave' record
                // We delete it so that the processing engine can decide whether 
                // it should be 'Present' (if logs exist) or stay empty/Absent.
                const [result] = await conn.execute(
                    `DELETE FROM attendance_daily 
                     WHERE employee_id = ? AND date = ? AND status = 'Leave'`,
                    [employeeId, d]
                );

                if (result.affectedRows > 0) {
                    // 2. Try to re-process logs for this date.
                    // If logs exist, it will recreate a 'Present' record.
                    try {
                        await conn.execute('CALL sp_process_attendance(?)', [d]);
                    } catch (e) {
                        console.error(`Failed to re-process attendance for ${d} during leave reversal:`, e);
                    }
                }
            }
            await conn.commit();
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }
}

module.exports = AttendanceModel;
