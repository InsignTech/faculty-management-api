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
            reason, attachment_path,
            substitute_employee_id
        } = data;

        // Verify employee is active
        const [empRows] = await pool.query('SELECT active FROM employee WHERE employee_id = ?', [employee_id]);
        if (!empRows.length || empRows[0].active === 0) {
            throw new Error('Adjustment requests can only be submitted for active employees.');
        }

        // Resolve approver config from employee_approver_configs
        const configType = type === 'Regularization' ? 'REGULARISATION' : 'ONDUTY';
        const [configRows] = await pool.execute(
            `SELECT
                COALESCE(eac.approver_1_id, e.reporting_manager_id,
                    (SELECT e2.employee_id FROM employee e2
                     JOIN app_role r2 ON e2.role_id = r2.role_id
                     WHERE r2.role IN ('Principal','principal') AND e2.active = 1 LIMIT 1)
                ) AS approver_1_id,
                eac.approver_2_id
             FROM employee e
             LEFT JOIN employee_approver_configs eac
                 ON eac.employee_id = e.employee_id AND eac.request_type = ?
             WHERE e.employee_id = ?`,
            [configType, employee_id]
        );

        const approver1 = configRows[0]?.approver_1_id || null;
        const approver2 = configRows[0]?.approver_2_id || null;

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
                        (employee_id, request_type, date, requested_in_time, requested_out_time, regularization_shift_type, reason, status, created_on, substitute_employee_id, approver_1_id, approver_2_id) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending', NOW(), ?, ?, ?)`,
                        [employee_id, type, d, requested_in_time || null, requested_out_time || null, regularization_shift_type || 'FullDay', reason, substitute_employee_id || null, approver1, approver2]
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
            (employee_id, request_type, date, requested_in_time, requested_out_time, regularization_shift_type, reason, status, created_on, substitute_employee_id, approver_1_id, approver_2_id) 
            VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending', NOW(), ?, ?, ?)`,
            [employee_id, type, targetDate, requested_in_time || null, requested_out_time || null, regularization_shift_type || 'FullDay', reason, substitute_employee_id || null, approver1, approver2]
        );

        return { adjustment_id: result.insertId };
    }

    // Approve an adjustment and trigger deduction recalculation
    static async approveAdjustment(adjustmentId, approverId, remarks, substituteEmployeeId = null) {
        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            // 1. Get the adjustment record
            const [adjRows] = await conn.execute(
                'SELECT * FROM attendance_regularization WHERE id = ?', [adjustmentId]
            );
            if (!adjRows.length) throw new Error('Adjustment not found');

            const adj = adjRows[0];
            if (adj.status !== 'Pending') {
                throw new Error('Only Pending requests can be approved');
            }

            const v_month = new Date(adj.date).getMonth() + 1;
            const v_year = new Date(adj.date).getFullYear();

            const currentLevel = adj.current_level || 1;

            // Check designated active level approver
            const expectedApproverId = (currentLevel === 1) ? adj.approver_1_id : adj.approver_2_id;
            if (approverId !== expectedApproverId) {
                const [roleRows] = await conn.execute(
                    `SELECT r.role FROM employee e 
                     JOIN app_role r ON e.role_id = r.role_id 
                     WHERE e.employee_id = ? AND e.active = 1`,
                    [approverId]
                );
                const role = roleRows[0]?.role?.toLowerCase();
                const isAdminOverride = ['super_admin'].includes(role);
                if (!isAdminOverride) {
                    throw new Error(`You are not the designated Level ${currentLevel} approver for this request.`);
                }
            }

            // 2. Check for overlapping approved states in attendance_daily (only on final approval)
            const isFinalApproval = !(currentLevel === 1 && adj.approver_2_id);

            const requestedShift = adj.regularization_shift_type || 'FullDay';

            if (isFinalApproval) {
                const [overlapCheck] = await conn.execute(
                    `SELECT leave_shift_type, regularization_shift_type, onduty_shift_type FROM attendance_daily 
                     WHERE employee_id = ? AND date = ?`,
                    [adj.employee_id, adj.date]
                );

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
            }

            // 3. Update request status / level
            if (currentLevel === 1 && adj.approver_2_id) {
                // Level 1 Approval only - Advance to Level 2
                await conn.execute(
                    `UPDATE attendance_regularization 
                     SET approver_1_remarks = ?, approver_1_action_on = NOW(), 
                         current_level = 2,
                         substitute_employee_id = COALESCE(?, substitute_employee_id)
                     WHERE id = ?`,
                    [remarks || '', substituteEmployeeId || null, adjustmentId]
                );
                await conn.commit();
                return { success: true, message: 'Level 1 approved, pending Level 2.' };
            } else {
                // Final Approval (either level 2, or level 1 with no level 2 configured)
                if (currentLevel === 1) {
                    await conn.execute(
                        `UPDATE attendance_regularization 
                         SET status = 'Approved', approved_by = ?, approved_on = NOW(), 
                             approver_1_remarks = ?, approver_1_action_on = NOW(),
                             reason = CONCAT(COALESCE(reason, ''), ' | Final Approval: ', ?),
                             substitute_employee_id = COALESCE(?, substitute_employee_id)
                         WHERE id = ?`,
                        [approverId, remarks || '', remarks || '', substituteEmployeeId || null, adjustmentId]
                    );
                } else {
                    await conn.execute(
                        `UPDATE attendance_regularization 
                         SET status = 'Approved', approved_by = ?, approved_on = NOW(), 
                             approver_2_remarks = ?, approver_2_action_on = NOW(),
                             reason = CONCAT(COALESCE(reason, ''), ' | Final Approval: ', ?),
                             substitute_employee_id = COALESCE(?, substitute_employee_id)
                         WHERE id = ?`,
                        [approverId, remarks || '', remarks || '', substituteEmployeeId || null, adjustmentId]
                    );
                }
            }

            // 4. Fetch current attendance state for smart merge
            const [attendanceRows] = await conn.execute(
                `SELECT status, shift_type, leave_shift_type, regularization_shift_type, onduty_shift_type, 
                        first_in_time, last_out_time 
                 FROM attendance_daily WHERE employee_id = ? AND date = ?`,
                [adj.employee_id, adj.date]
            );
            const row = attendanceRows[0] || { first_in_time: null, last_out_time: null };

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
                let finalOnDutyShift = requestedShift;
                // If already partially covered, maybe promote
                if (row.onduty_shift_type && row.onduty_shift_type !== 'FullDay' && row.onduty_shift_type !== requestedShift) {
                    finalOnDutyShift = 'FullDay';
                }

                // Check coverage
                const isFirstHalfCovered = (row.shift_type === 'FirstHalf' || row.shift_type === 'FullDay' ||
                    row.leave_shift_type === 'FirstHalf' || row.leave_shift_type === 'FullDay' ||
                    row.regularization_shift_type === 'FirstHalf' || row.regularization_shift_type === 'FullDay' ||
                    finalOnDutyShift === 'FirstHalf' || finalOnDutyShift === 'FullDay');

                const isSecondHalfCovered = (row.shift_type === 'SecondHalf' || row.shift_type === 'FullDay' ||
                    row.leave_shift_type === 'SecondHalf' || row.leave_shift_type === 'FullDay' ||
                    row.regularization_shift_type === 'SecondHalf' || row.regularization_shift_type === 'FullDay' ||
                    finalOnDutyShift === 'SecondHalf' || finalOnDutyShift === 'FullDay');

                let deduction = (isFirstHalfCovered && isSecondHalfCovered) ? 0.00 : 0.50;
                if (!isFirstHalfCovered && !isSecondHalfCovered) deduction = 1.00;

                // For OnDuty, we usually set placeholder times if it covers the shift
                let inTime = row.first_in_time;
                let outTime = row.last_out_time;
                if (finalOnDutyShift === 'FullDay') {
                    inTime = '09:00:00';
                    outTime = '17:00:00';
                } else if (finalOnDutyShift === 'FirstHalf' && !inTime) {
                    inTime = '09:00:00';
                } else if (finalOnDutyShift === 'SecondHalf' && !outTime) {
                    outTime = '17:00:00';
                }

                await conn.execute(
                    `UPDATE attendance_daily SET status = 'Present', onduty_shift_type = ?, deduction_days = ?,
                            first_in_time = ?, last_out_time = ?
                     WHERE employee_id = ? AND date = ?`,
                    [finalOnDutyShift, deduction, inTime || null, outTime || null, adj.employee_id, adj.date]
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
        // Load the adjustment to check current level
        const [adjRows] = await pool.execute(
            'SELECT current_level, approver_1_id, approver_2_id FROM attendance_regularization WHERE id = ?',
            [adjustmentId]
        );
        if (!adjRows.length) throw new Error('Adjustment not found');
        const adj = adjRows[0];
        const currentLevel = adj.current_level || 1;

        // Check designated active level approver
        const expectedApproverId = (currentLevel === 1) ? adj.approver_1_id : adj.approver_2_id;
        if (approverId !== expectedApproverId) {
            const [roleRows] = await pool.execute(
                `SELECT r.role FROM employee e 
                 JOIN app_role r ON e.role_id = r.role_id 
                 WHERE e.employee_id = ? AND e.active = 1`,
                [approverId]
            );
            const role = roleRows[0]?.role?.toLowerCase();
            const isAdminOverride = ['super_admin'].includes(role);
            if (!isAdminOverride) {
                throw new Error(`You are not the designated Level ${currentLevel} approver for this request.`);
            }
        }

        let query = '';
        let params = [];

        if (currentLevel === 1) {
            query = `UPDATE attendance_regularization 
                     SET status = 'Rejected', approved_by = ?, approved_on = NOW(),
                         approver_1_remarks = ?, approver_1_action_on = NOW()
                     WHERE id = ?`;
            params = [approverId, remarks || '', adjustmentId];
        } else {
            query = `UPDATE attendance_regularization 
                     SET status = 'Rejected', approved_by = ?, approved_on = NOW(),
                         approver_2_remarks = ?, approver_2_action_on = NOW()
                     WHERE id = ?`;
            params = [approverId, remarks || '', adjustmentId];
        }

        const [rows] = await pool.execute(query, params);
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
            SELECT aj.*, e.employee_name as approver_name,
                   ea1.employee_name AS approver_1_name,
                   ea1.employee_code AS approver_1_code,
                   ea2.employee_name AS approver_2_name,
                   ea2.employee_code AS approver_2_code,
                   ad.first_in_time AS actual_in_time,
                   ad.last_out_time AS actual_out_time,
                   ad.status AS actual_status,
                   sub.employee_name AS substitute_name,
                   sub.employee_code AS substitute_code
            FROM attendance_regularization aj 
            LEFT JOIN employee e ON aj.approved_by = e.employee_id 
            LEFT JOIN employee ea1 ON ea1.employee_id = aj.approver_1_id
            LEFT JOIN employee ea2 ON ea2.employee_id = aj.approver_2_id
            LEFT JOIN employee sub ON sub.employee_id = aj.substitute_employee_id
            LEFT JOIN attendance_daily ad ON ad.employee_id = aj.employee_id AND ad.date = aj.date
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

    // Admin: Get all pending adjustments (legacy — kept for compatibility)
    static async getPendingAdjustments() {
        const [rows] = await pool.query(`
            SELECT aj.*, e.employee_name, e.employee_code,
                   ap.employee_name AS approver_name
            FROM attendance_regularization aj 
            JOIN employee e ON aj.employee_id = e.employee_id
            LEFT JOIN employee ap ON ap.employee_id = aj.approved_by
            WHERE aj.status = 'Pending' 
            ORDER BY aj.created_on ASC
        `);
        return rows;
    }

    // Manager/HOD: Get pending adjustments for all subordinates (legacy)
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
            SELECT aj.*, e.employee_name, e.employee_code,
                   ap.employee_name AS approver_name
            FROM attendance_regularization aj 
            JOIN employee e ON aj.employee_id = e.employee_id
            LEFT JOIN employee ap ON ap.employee_id = aj.approved_by
            WHERE aj.employee_id IN (SELECT employee_id FROM subordinates)
              AND aj.status = 'Pending'
            ORDER BY aj.created_on ASC
        `;
        const [rows] = await pool.execute(query, [managerId]);
        return rows;
    }

    /**
     * Paginated approval queue — supports status filter.
     * isAdmin = true  → all records
     * isAdmin = false → manager sees own subordinate records
     */
    static async getApprovalQueue({ isAdmin, managerId, status = 'Pending', page = 1, limit = 10 }) {
        const offset = (page - 1) * limit;
        const statusFilter = (status && status !== 'All') ? status : null;

        let dataQuery, countQuery, params = [], countParams = [];

        if (isAdmin) {
            dataQuery = `
                SELECT aj.*, e.employee_name, e.employee_code,
                       d.departmentname AS department_name,
                       des.designation AS employee_designation,
                       ap.employee_name AS approver_name,
                       ea1.employee_name AS approver_1_name,
                       ea1.employee_code AS approver_1_code,
                       ea2.employee_name AS approver_2_name,
                       ea2.employee_code AS approver_2_code,
                       ad.first_in_time AS actual_in_time,
                       ad.last_out_time AS actual_out_time,
                       ad.status AS actual_status,
                       sub.employee_name AS substitute_name,
                       sub.employee_code AS substitute_code
                FROM attendance_regularization aj
                JOIN employee e ON aj.employee_id = e.employee_id
                LEFT JOIN department d ON e.department_id = d.department_id
                LEFT JOIN designation des ON e.designation_id = des.designation_id
                LEFT JOIN employee ap  ON ap.employee_id  = aj.approved_by
                LEFT JOIN employee ea1 ON ea1.employee_id = aj.approver_1_id
                LEFT JOIN employee ea2 ON ea2.employee_id = aj.approver_2_id
                LEFT JOIN employee sub ON sub.employee_id = aj.substitute_employee_id
                LEFT JOIN attendance_daily ad ON ad.employee_id = aj.employee_id AND ad.date = aj.date
                WHERE 1=1
                ${statusFilter ? 'AND aj.status = ?' : ""}
                ORDER BY aj.created_on DESC
                LIMIT ? OFFSET ?`;
            countQuery = `
                SELECT COUNT(*) AS total FROM attendance_regularization aj
                WHERE 1=1 ${statusFilter ? 'AND aj.status = ?' : ''}`;
            if (statusFilter) { params.push(statusFilter); countParams.push(statusFilter); }
            params.push(parseInt(limit), parseInt(offset));
        } else {
            const approverConditions = (statusFilter === 'Pending')
                ? `OR (aj.current_level = 1 AND aj.approver_1_id = ?)
                   OR (aj.current_level = 2 AND aj.approver_2_id = ?)`
                : `OR aj.approver_1_id = ?
                   OR aj.approver_2_id = ?`;

            dataQuery = `
                WITH RECURSIVE subordinates AS (
                    SELECT employee_id FROM employee WHERE reporting_manager_id = ?
                    UNION ALL
                    SELECT e.employee_id FROM employee e
                    INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
                )
                SELECT aj.*, e.employee_name, e.employee_code,
                       d.departmentname AS department_name,
                       des.designation AS employee_designation,
                       ap.employee_name AS approver_name,
                       ea1.employee_name AS approver_1_name,
                       ea1.employee_code AS approver_1_code,
                       ea2.employee_name AS approver_2_name,
                       ea2.employee_code AS approver_2_code,
                       ad.first_in_time AS actual_in_time,
                       ad.last_out_time AS actual_out_time,
                       ad.status AS actual_status,
                       sub.employee_name AS substitute_name,
                       sub.employee_code AS substitute_code
                FROM attendance_regularization aj
                JOIN employee e ON aj.employee_id = e.employee_id
                LEFT JOIN department d ON e.department_id = d.department_id
                LEFT JOIN designation des ON e.designation_id = des.designation_id
                LEFT JOIN employee ap  ON ap.employee_id  = aj.approved_by
                LEFT JOIN employee ea1 ON ea1.employee_id = aj.approver_1_id
                LEFT JOIN employee ea2 ON ea2.employee_id = aj.approver_2_id
                LEFT JOIN employee sub ON sub.employee_id = aj.substitute_employee_id
                LEFT JOIN attendance_daily ad ON ad.employee_id = aj.employee_id AND ad.date = aj.date
                WHERE (aj.employee_id IN (SELECT employee_id FROM subordinates)
                   ${approverConditions})
                ${statusFilter ? 'AND aj.status = ?' : ''}
                ORDER BY aj.created_on DESC
                LIMIT ? OFFSET ?`;

            countQuery = `
                WITH RECURSIVE subordinates AS (
                    SELECT employee_id FROM employee WHERE reporting_manager_id = ?
                    UNION ALL
                    SELECT e.employee_id FROM employee e
                    INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
                )
                SELECT COUNT(*) AS total FROM attendance_regularization aj
                WHERE (aj.employee_id IN (SELECT employee_id FROM subordinates)
                   ${approverConditions})
                ${statusFilter ? 'AND aj.status = ?' : ''}`;

            params.push(managerId, managerId, managerId);
            countParams.push(managerId, managerId, managerId);
            if (statusFilter) { params.push(statusFilter); countParams.push(statusFilter); }
            params.push(parseInt(limit), parseInt(offset));
        }

        const [rows] = await pool.query(dataQuery, params);
        const [countRows] = await pool.query(countQuery, countParams);
        return { adjustments: rows, total: countRows[0]?.total || 0 };
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


    // Bulk insert machine logs
    static async insertMachineLogsMesEdathala(logs) {
        if (!logs || logs.length === 0) return 0;

        // Prepare bulk insert values
        // Expecting logs to be [{ employee_id: 123, punch_time: '2024-04-04 09:00:00' }, ...]
        const values = logs.map(log => [log.employee_id, log.punch_time]);

        const query = 'INSERT IGNORE INTO attendance_detail_log_mesedathala (employee_code, punch_time) VALUES ?';
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

    // Super Admin: Direct Daily Attendance Update (upsert)
    static async superAdminUpdateDaily(data) {
        const {
            employee_id,
            date,
            status,
            first_in_time,
            last_out_time,
            is_late,
            is_early_leaving,
            deduction_days,
            regularization_shift_type,
            onduty_shift_type,
            leave_shift_type
        } = data;

        let worked_mins = 0;
        if (first_in_time && last_out_time) {
            const [inH, inM, inS] = first_in_time.split(':').map(Number);
            const [outH, outM, outS] = last_out_time.split(':').map(Number);
            const inMins = inH * 60 + (inM || 0);
            const outMins = outH * 60 + (outM || 0);
            if (outMins >= inMins) {
                worked_mins = outMins - inMins;
            }
        }

        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            await conn.execute(
                `INSERT INTO attendance_daily (
                    employee_id, date, status, first_in_time, last_out_time, worked_mins,
                    is_late, is_early_leaving, deduction_days,
                    regularization_shift_type, onduty_shift_type, leave_shift_type,
                    created_on
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
                ON DUPLICATE KEY UPDATE
                    status = VALUES(status),
                    first_in_time = VALUES(first_in_time),
                    last_out_time = VALUES(last_out_time),
                    worked_mins = VALUES(worked_mins),
                    is_late = VALUES(is_late),
                    is_early_leaving = VALUES(is_early_leaving),
                    deduction_days = VALUES(deduction_days),
                    regularization_shift_type = VALUES(regularization_shift_type),
                    onduty_shift_type = VALUES(onduty_shift_type),
                    leave_shift_type = VALUES(leave_shift_type)`,
                [
                    employee_id, date, status,
                    first_in_time || null, last_out_time || null, worked_mins,
                    is_late || 0, is_early_leaving || 0, deduction_days || 0.00,
                    regularization_shift_type || null, onduty_shift_type || null, leave_shift_type || null
                ]
            );

            await conn.commit();
            return { success: true, message: 'Daily attendance updated successfully.' };
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }

    // Super Admin: Direct Adjustment Application (Bypass limits, auto-approve)
    static async superAdminCreateAdjustment(data, approverId) {
        const { employee_id, type, date, from_date, to_date, requested_in_time, requested_out_time, regularization_shift_type, reason } = data;

        // Verify employee is active
        const [empRows] = await pool.query('SELECT active FROM employee WHERE employee_id = ?', [employee_id]);
        if (!empRows.length || empRows[0].active === 0) {
            throw new Error('Adjustment requests can only be submitted for active employees.');
        }

        const targetDate = date || from_date;
        const requestedShift = regularization_shift_type || 'FullDay';

        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            const [result] = await conn.execute(
                `INSERT INTO attendance_regularization 
                (employee_id, request_type, date, requested_in_time, requested_out_time, regularization_shift_type, reason, status, created_on) 
                VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending', NOW())`,
                [employee_id, type, targetDate, requested_in_time || null, requested_out_time || null, requestedShift, reason]
            );

            const adjustmentId = result.insertId;

            await conn.commit();

            const approveRes = await this.approveAdjustment(adjustmentId, approverId, 'Super Admin Direct Bypass Approval');

            return { success: true, adjustment_id: adjustmentId, ...approveRes };
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }
}

module.exports = AttendanceModel;

