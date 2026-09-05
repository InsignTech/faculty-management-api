const crypto = require('crypto');
const pool = require('../config/db');
const SettingsModel = require('./settingsModel');

class AttendanceModel {
    // Process raw logs for a specific date
    static async processLogs(date) {
        const [rows] = await pool.execute('CALL sp_process_attendance_shiftwise(?)', [date]);
        return rows[0][0];
    }

    // Process raw logs for all missing dates up to today
    static async processMissedLogs() {
        const datesToProcess = new Set();
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        try {
            // 1. Get dates with unprocessed logs (processed_flag = 0) from the last 30 days
            const [unprocessedRows] = await pool.query(
                `SELECT DISTINCT DATE(punch_time) as log_date 
                 FROM attendance_punches_detail 
                 WHERE processed_flag = 0 
                   AND punch_time >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)`
            );
            for (const row of unprocessedRows) {
                if (row.log_date) {
                    const dateStr = new Date(row.log_date).toISOString().split('T')[0];
                    datesToProcess.add(dateStr);
                }
            }

            // 2. Determine start date for sequential processing
            let latestDate = null;
            try {
                const [logRows] = await pool.query(
                    "SELECT MAX(process_date) as latest_date FROM attendance_process_log WHERE status = 'Success'"
                );
                latestDate = logRows[0]?.latest_date;
            } catch (err) {
                // Table might not exist or other error, fallback to attendance_daily
            }

            if (!latestDate) {
                const [dailyRows] = await pool.query("SELECT MAX(date) as latest_date FROM attendance");
                latestDate = dailyRows[0]?.latest_date;
            }

            let startDate;
            if (!latestDate) {
                const [minLog] = await pool.query("SELECT DATE(MIN(punch_time)) as min_date FROM attendance_punches_detail");
                if (minLog[0]?.min_date) {
                    startDate = new Date(minLog[0].min_date);
                } else {
                    startDate = new Date();
                    startDate.setDate(startDate.getDate() - 30); // Default to last 30 days
                }
            } else {
                startDate = new Date(latestDate);
                startDate.setDate(startDate.getDate() + 1);
            }

            startDate.setHours(0, 0, 0, 0);

            // Limit backward search to max 35 days to avoid timeouts
            const maxPastDate = new Date();
            maxPastDate.setDate(maxPastDate.getDate() - 35);
            maxPastDate.setHours(0, 0, 0, 0);
            if (startDate < maxPastDate) {
                startDate = maxPastDate;
            }

            // 3. Add all sequential missing days up to today
            let currentDate = new Date(startDate);
            while (currentDate <= today) {
                const year = currentDate.getFullYear();
                const month = String(currentDate.getMonth() + 1).padStart(2, '0');
                const day = String(currentDate.getDate()).padStart(2, '0');
                const dateStr = `${year}-${month}-${day}`;
                datesToProcess.add(dateStr);
                currentDate.setDate(currentDate.getDate() + 1);
            }
        } catch (error) {
            console.error("Error determining dates to process:", error.message);
        }

        // 4. Sort dates chronologically
        const sortedDates = Array.from(datesToProcess).sort();
        let totalProcessed = 0;
        let daysProcessed = 0;

        // 5. Process each date sequentially
        for (const dateStr of sortedDates) {
            try {
                // Execute stored procedure
                const [resultRows] = await pool.execute('CALL sp_process_attendance_shiftwise(?)', [dateStr]);
                const rowsProcessed = resultRows[0]?.[0]?.processed_rows || 0;

                totalProcessed += rowsProcessed;
                daysProcessed++;

                // Log success to attendance_process_log
                await pool.execute(
                    `INSERT INTO attendance_process_log (process_date, status, message, processed_on) 
                     VALUES (?, 'Success', 'Processed successfully', NOW()) 
                     ON DUPLICATE KEY UPDATE status = VALUES(status), message = VALUES(message), processed_on = VALUES(processed_on)`,
                    [dateStr]
                );
            } catch (error) {
                console.error(`Error processing attendance for date ${dateStr}:`, error.message);
                
                // Log failure to attendance_process_log
                try {
                    await pool.execute(
                        `INSERT INTO attendance_process_log (process_date, status, message, processed_on) 
                         VALUES (?, 'Failed', ?, NOW()) 
                         ON DUPLICATE KEY UPDATE status = VALUES(status), message = VALUES(message), processed_on = VALUES(processed_on)`,
                        [dateStr, error.message.substring(0, 255)]
                    );
                } catch (logErr) {
                    console.error("Failed to write error to process log:", logErr.message);
                }
            }
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

    /**
     * Helper to validate a date range for adjustments (e.g. On-Duty).
     * Filters out non-working days (weekends, holidays), pre-approved leaves,
     * duplicate adjustments, and days already marked Present.
     */
    static async validateAndFilterRangeDates({ employee_id, type = 'OnDuty', from_date, to_date, shift_type = 'FullDay' }) {
        if (!from_date || !to_date) {
            throw new Error('Both from_date and to_date are required for range validation.');
        }

        const requestedShift = shift_type || 'FullDay';

        // 1. Generate chronological list of dates (using UTC to prevent timezone skew)
        const [startYear, startMonth, startDay] = from_date.split('-').map(Number);
        const [endYear, endMonth, endDay] = to_date.split('-').map(Number);
        const curr = new Date(Date.UTC(startYear, startMonth - 1, startDay));
        const end = new Date(Date.UTC(endYear, endMonth - 1, endDay));

        if (curr > end) {
            throw new Error('from_date must be before or equal to to_date.');
        }

        const allDates = [];
        while (curr <= end) {
            const y = curr.getUTCFullYear();
            const m = String(curr.getUTCMonth() + 1).padStart(2, '0');
            const d = String(curr.getUTCDate()).padStart(2, '0');
            allDates.push(`${y}-${m}-${d}`);
            curr.setUTCDate(curr.getUTCDate() + 1);
        }

        // 2. Batch fetch Holidays & Weekends from holiday_master
        const [holidays] = await pool.query(
            `SELECT holiday_name, holiday_type, 
                    DATE_FORMAT(holiday_start_date, '%Y-%m-%d') AS start_date,
                    DATE_FORMAT(holiday_end_date, '%Y-%m-%d') AS end_date
             FROM holiday_master
             WHERE is_active = 1
               AND (employee_id = -1 OR employee_id = ?)
               AND holiday_start_date <= ? AND holiday_end_date >= ?`,
            [employee_id, to_date, from_date]
        );

        // 3. Batch fetch Approved Leaves from leave_requests
        const [leaves] = await pool.query(
            `SELECT leave_request_id, leave_type, leave_half_type,
                    DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
                    DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date
             FROM leave_requests
             WHERE employee_id = ?
               AND status = 'Approved'
               AND start_date <= ? AND end_date >= ?`,
            [employee_id, to_date, from_date]
        );

        // 4. Batch fetch Existing Adjustments from attendance_regularization
        const [existingAdjustments] = await pool.query(
            `SELECT id, batch_id, request_type, regularization_shift_type, status,
                    DATE_FORMAT(date, '%Y-%m-%d') AS date
             FROM attendance_regularization
             WHERE employee_id = ?
               AND status IN ('Pending', 'Approved')
               AND date BETWEEN ? AND ?`,
            [employee_id, from_date, to_date]
        );

        // 5. Batch fetch daily Attendance records (for past processed dates)
        const [attendanceRows] = await pool.query(
            `SELECT shift_type, status, DATE_FORMAT(date, '%Y-%m-%d') AS date
             FROM attendance
             WHERE employee_id = ?
               AND date BETWEEN ? AND ?`,
            [employee_id, from_date, to_date]
        );

        const applicableDates = [];
        const skippedWeekends = [];
        const skippedHolidays = [];
        const skippedLeaves = [];
        const skippedExisting = [];
        const skippedPresent = [];

        for (const dateStr of allDates) {
            const dateObj = new Date(dateStr + 'T00:00:00Z');
            const dayOfWeek = dateObj.getUTCDay(); // 0 = Sunday

            // A. Check Weekend: Universal Sunday OR marked as WeekEnd in holiday_master
            const isWeekendHoliday = holidays.find(h => 
                h.holiday_type === 'WeekEnd' && dateStr >= h.start_date && dateStr <= h.end_date
            );
            if (dayOfWeek === 0 || isWeekendHoliday) {
                skippedWeekends.push({
                    date: dateStr,
                    reason: isWeekendHoliday ? (isWeekendHoliday.holiday_name || 'Weekly Off') : 'Sunday Weekly Off'
                });
                continue;
            }

            // B. Check Public / Other Holidays
            const holiday = holidays.find(h => 
                h.holiday_type !== 'WeekEnd' && dateStr >= h.start_date && dateStr <= h.end_date
            );
            if (holiday) {
                skippedHolidays.push({
                    date: dateStr,
                    holiday_name: holiday.holiday_name,
                    holiday_type: holiday.holiday_type
                });
                continue;
            }

            // C. Check Approved Leaves (either from leave_requests or processed attendance)
            const leave = leaves.find(l => {
                if (dateStr >= l.start_date && dateStr <= l.end_date) {
                    if (l.leave_half_type === 'FullDay' || requestedShift === 'FullDay' || l.leave_half_type === requestedShift) {
                        return true;
                    }
                }
                return false;
            });
            const attLeave = attendanceRows.find(a => 
                a.date === dateStr && a.status === 'Leave' &&
                (a.shift_type === 'FullDay' || requestedShift === 'FullDay' || a.shift_type === requestedShift)
            );

            if (leave || attLeave) {
                skippedLeaves.push({
                    date: dateStr,
                    leave_type: leave ? leave.leave_type : 'Approved Leave',
                    shift: leave ? leave.leave_half_type : (attLeave ? attLeave.shift_type : 'FullDay')
                });
                continue;
            }

            // D. Check Existing Adjustments (Pending/Approved)
            const existingAdj = existingAdjustments.find(ea => 
                ea.date === dateStr && 
                (ea.regularization_shift_type === 'FullDay' || requestedShift === 'FullDay' || ea.regularization_shift_type === requestedShift)
            );
            if (existingAdj) {
                skippedExisting.push({
                    date: dateStr,
                    request_type: existingAdj.request_type,
                    status: existingAdj.status,
                    shift: existingAdj.regularization_shift_type
                });
                continue;
            }

            // E. Check if already marked as Present (for past dates)
            const presentRow = attendanceRows.find(a => a.date === dateStr && a.status === 'Present');
            if (presentRow) {
                skippedPresent.push({
                    date: dateStr,
                    reason: 'Already marked as Present'
                });
                continue;
            }

            // F. Date is valid for adjustment
            applicableDates.push(dateStr);
        }

        return {
            total_calendar_days: allDates.length,
            applicable_days: applicableDates.length,
            applicable_dates: applicableDates,
            skipped: {
                weekends: skippedWeekends,
                holidays: skippedHolidays,
                leaves: skippedLeaves,
                existing_adjustments: skippedExisting,
                already_present: skippedPresent,
                total_skipped: skippedWeekends.length + skippedHolidays.length + skippedLeaves.length + skippedExisting.length + skippedPresent.length
            }
        };
    }

    // Handle Date Range for On-Duty
    static async handleDateRangeOnDuty(data, approver1, approver2) {
        const {
            employee_id, type, from_date, to_date,
            requested_in_time, requested_out_time,
            regularization_shift_type,
            reason, substitute_employee_id
        } = data;

        const shiftType = regularization_shift_type || 'FullDay';
        const rangeAnalysis = await this.validateAndFilterRangeDates({
            employee_id,
            type,
            from_date,
            to_date,
            shift_type: shiftType
        });

        if (rangeAnalysis.applicable_days === 0) {
            const reasons = [];
            if (rangeAnalysis.skipped.weekends.length) reasons.push(`${rangeAnalysis.skipped.weekends.length} weekend(s)`);
            if (rangeAnalysis.skipped.holidays.length) reasons.push(`${rangeAnalysis.skipped.holidays.length} holiday(s)`);
            if (rangeAnalysis.skipped.leaves.length) reasons.push(`${rangeAnalysis.skipped.leaves.length} approved leave(s)`);
            if (rangeAnalysis.skipped.existing_adjustments.length) reasons.push(`${rangeAnalysis.skipped.existing_adjustments.length} existing adjustment(s)`);
            if (rangeAnalysis.skipped.already_present.length) reasons.push(`${rangeAnalysis.skipped.already_present.length} already present day(s)`);

            throw new Error(
                `No valid working days found in the selected range (${from_date} to ${to_date}). Excluded: ${reasons.join(', ')}.`
            );
        }

        const batchId = crypto.randomUUID();
        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            const skippedSummaryJson = JSON.stringify({
                weekends: rangeAnalysis.skipped.weekends.length,
                holidays: rangeAnalysis.skipped.holidays.length,
                leaves: rangeAnalysis.skipped.leaves.length,
                existing_adjustments: rangeAnalysis.skipped.existing_adjustments.length,
                already_present: rangeAnalysis.skipped.already_present.length,
                total_skipped: rangeAnalysis.skipped.total_skipped,
                skipped: rangeAnalysis.skipped
            });

            for (const d of rangeAnalysis.applicable_dates) {
                await conn.execute(
                    `INSERT INTO attendance_regularization 
                    (batch_id, employee_id, request_type, date, requested_in_time, requested_out_time, regularization_shift_type, reason, status, created_on, substitute_employee_id, approver_1_id, approver_2_id, applied_by_id, is_proxy, range_from_date, range_to_date, range_calendar_days, range_skipped_summary) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Pending', NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                    [batchId, employee_id, type, d, requested_in_time || null, requested_out_time || null, shiftType, reason, substitute_employee_id || null, approver1, approver2, data.applied_by_id || null, data.is_proxy || 0, from_date, to_date, rangeAnalysis.total_calendar_days, skippedSummaryJson]
                );
            }

            await conn.commit();
            return {
                success: true,
                count: rangeAnalysis.applicable_days,
                batch_id: batchId,
                range_analysis: rangeAnalysis
            };
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
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
            return this.handleDateRangeOnDuty(data, approver1, approver2);
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

        // 3. Approved State Validation (Check attendance)
        const [attendanceRows] = await pool.query(
            `SELECT status, first_in_time, last_out_time, is_late, is_early_leaving, shift_type 
             FROM attendance 
             WHERE employee_id = ? AND date = ?`,
            [employee_id, targetDate]
        );

        if (attendanceRows.length > 0) {
            // Validation for Regularization
            if (type === 'Regularization') {
                if (new Date(targetDate) > new Date()) {
                    throw new Error('Regularization cannot be requested for future dates.');
                }

                // Disallow regularization on weekend/holiday if employee never punched
                const isHolidayWithoutPunches = attendanceRows.some(r => 
                    ['WeekEnd', 'Public Holiday', 'Exceptional Holiday', 'Vacation'].includes(r.status) &&
                    !r.first_in_time && !r.last_out_time
                );
                if (isHolidayWithoutPunches) {
                    throw new Error('Cannot regularize attendance on a Weekend or Public Holiday without punch records.');
                }

                // Check if already regularized
                const isAlreadyRegularized = attendanceRows.some(r => r.status === 'Regularized' && (r.shift_type === 'FullDay' || r.shift_type === requestedShift));
                if (isAlreadyRegularized) {
                    throw new Error(`This ${requestedShift} shift is already regularized.`);
                }

                // Strict "Present" Check
                const targetRow = attendanceRows.find(r => r.shift_type === requestedShift) || attendanceRows.find(r => r.shift_type === 'FullDay');
                if (targetRow && targetRow.status === 'Present' && targetRow.first_in_time && targetRow.last_out_time) {
                    if (requestedShift === 'FullDay' && targetRow.is_late === 0 && targetRow.is_early_leaving === 0) {
                        throw new Error('Attendance is already marked as complete and on-time for this date.');
                    }
                    if (requestedShift === 'FirstHalf' && targetRow.is_late === 0) {
                        throw new Error('You were not late in the 1st half, regularization is not required.');
                    }
                    if (requestedShift === 'SecondHalf' && targetRow.is_early_leaving === 0) {
                        throw new Error('You did not leave early in the 2nd half, regularization is not required.');
                    }
                }
            }

            // Cross-column overlap check
            const activeStates = attendanceRows.filter(r => ['Leave', 'Regularized', 'OnDuty'].includes(r.status));

            for (const state of activeStates) {
                if (state.shift_type === 'FullDay' || requestedShift === 'FullDay' || state.shift_type === requestedShift) {
                    throw new Error(`Overlap Error: This shift is already covered by an approved ${state.status} (${state.shift_type}).`);
                }
            }
        }

        const batchId = crypto.randomUUID();
        const [result] = await pool.execute(
            `INSERT INTO attendance_regularization 
            (batch_id, employee_id, request_type, date, requested_in_time, requested_out_time, regularization_shift_type, reason, status, created_on, substitute_employee_id, approver_1_id, approver_2_id, applied_by_id, is_proxy) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Pending', NOW(), ?, ?, ?, ?, ?)`,
            [batchId, employee_id, type, targetDate, requested_in_time || null, requested_out_time || null, regularization_shift_type || 'FullDay', reason, substitute_employee_id || null, approver1, approver2, data.applied_by_id || null, data.is_proxy || 0]
        );

        return { adjustment_id: result.insertId, batch_id: batchId };
    }

    // Preview adjustment range before submission
    static async previewAdjustmentRange(params) {
        return this.validateAndFilterRangeDates(params);
    }

    // Helper to resolve batch rows safely without MySQL string-to-int type coercion on integer column `id`
    static async _resolveBatchRows(connOrPool, batchIdentifier) {
        if (!batchIdentifier) return { batchId: null, rows: [] };
        const strId = String(batchIdentifier).trim();
        let batchId = strId;

        // 1. Try lookup by batch_id first
        let [rows] = await connOrPool.execute(
            'SELECT * FROM attendance_regularization WHERE batch_id = ?',
            [batchId]
        );

        // 2. If not found by batch_id and identifier is purely numeric, lookup by integer id
        if (!rows.length && /^\d+$/.test(strId)) {
            const numId = Number(strId);
            const [idRows] = await connOrPool.execute(
                'SELECT * FROM attendance_regularization WHERE id = ?',
                [numId]
            );
            if (idRows.length) {
                batchId = idRows[0].batch_id || strId;
                if (idRows[0].batch_id) {
                    [rows] = await connOrPool.execute(
                        'SELECT * FROM attendance_regularization WHERE batch_id = ?',
                        [batchId]
                    );
                } else {
                    rows = idRows;
                }
            }
        }

        return { batchId, rows };
    }

    // Approve an adjustment batch (or single record) and trigger deduction recalculation
    static async approveBatchAdjustment(batchIdentifier, approverId, remarks, substituteEmployeeId = null) {
        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            // 1. Resolve batch rows safely
            const { batchId, rows: adjRows } = await this._resolveBatchRows(conn, batchIdentifier);
            if (!adjRows.length) throw new Error('Adjustment batch not found');

            const pendingRows = adjRows.filter(r => r.status === 'Pending');
            if (!pendingRows.length) {
                throw new Error('No pending requests found in this batch (already processed)');
            }

            const representative = pendingRows[0];
            const currentLevel = representative.current_level || 1;

            // Check designated active level approver
            const expectedApproverId = (currentLevel === 1) ? representative.approver_1_id : representative.approver_2_id;
            if (approverId !== expectedApproverId) {
                const [roleRows] = await conn.execute(
                    `SELECT r.role FROM employee e 
                     JOIN app_role r ON e.role_id = r.role_id 
                     WHERE e.employee_id = ? AND e.active = 1`,
                    [approverId]
                );
                const role = roleRows[0]?.role?.toLowerCase();
                const isAdminOverride = ['super_admin', 'admin', 'principal'].includes(role);
                if (!isAdminOverride) {
                    throw new Error(`You are not the designated Level ${currentLevel} approver for this request.`);
                }
            }

            // 2. Check for overlapping approved states in attendance (only on final approval)
            const isFinalApproval = !(currentLevel === 1 && representative.approver_2_id);
            if (isFinalApproval) {
                for (const adj of pendingRows) {
                    const requestedShift = adj.regularization_shift_type || 'FullDay';
                    const [overlapCheck] = await conn.execute(
                        `SELECT shift_type, status FROM attendance WHERE employee_id = ? AND date = ?`,
                        [adj.employee_id, adj.date]
                    );

                    if (overlapCheck.length > 0) {
                        const activeShifts = overlapCheck.filter(r => ['Leave', 'Regularized', 'OnDuty'].includes(r.status));
                        for (const s of activeShifts) {
                            if (s.shift_type === 'FullDay' || requestedShift === 'FullDay' || s.shift_type === requestedShift) {
                                throw new Error(`Approval Error for date ${adj.date}: This shift is already covered by an approved ${s.status} (${s.shift_type}).`);
                            }
                        }
                    }
                }
            }

            // 3. Update request status / level for all pending records in batch
            if (currentLevel === 1 && representative.approver_2_id) {
                // Level 1 Approval only - Advance all in batch to Level 2
                await conn.execute(
                    `UPDATE attendance_regularization 
                     SET approver_1_remarks = ?, approver_1_action_on = NOW(), 
                         current_level = 2,
                         substitute_employee_id = COALESCE(?, substitute_employee_id)
                     WHERE batch_id = ? AND status = 'Pending'`,
                    [remarks || '', substituteEmployeeId || null, batchId]
                );
                await conn.commit();
                return { success: true, count: pendingRows.length, message: `Level 1 approved for ${pendingRows.length} day(s), pending Level 2.` };
            } else {
                // Final Approval (either level 2, or level 1 with no level 2 configured)
                if (currentLevel === 1) {
                    await conn.execute(
                        `UPDATE attendance_regularization 
                         SET status = 'Approved', approved_by = ?, approved_on = NOW(), 
                             approver_1_remarks = ?, approver_1_action_on = NOW(),
                             reason = CONCAT(COALESCE(reason, ''), ' | Final Approval: ', ?),
                             substitute_employee_id = COALESCE(?, substitute_employee_id)
                         WHERE batch_id = ? AND status = 'Pending'`,
                        [approverId, remarks || '', remarks || '', substituteEmployeeId || null, batchId]
                    );
                } else {
                    await conn.execute(
                        `UPDATE attendance_regularization 
                         SET status = 'Approved', approved_by = ?, approved_on = NOW(), 
                             approver_2_remarks = ?, approver_2_action_on = NOW(),
                             reason = CONCAT(COALESCE(reason, ''), ' | Final Approval: ', ?),
                             substitute_employee_id = COALESCE(?, substitute_employee_id)
                         WHERE batch_id = ? AND status = 'Pending'`,
                        [approverId, remarks || '', remarks || '', substituteEmployeeId || null, batchId]
                    );
                }

                // Rebuild attendance state for each unique date in the batch
                const uniqueDates = [...new Set(pendingRows.map(r => new Date(r.date).toISOString().split('T')[0]))];
                for (const d of uniqueDates) {
                    await conn.execute('CALL sp_process_attendance_shiftwise(?)', [d]);
                }

                await conn.commit();
                return { success: true, count: pendingRows.length, message: `Adjustment approved for ${pendingRows.length} day(s).` };
            }
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }

    // Approve an adjustment (delegates to approveBatchAdjustment)
    static async approveAdjustment(adjustmentId, approverId, remarks, substituteEmployeeId = null) {
        return this.approveBatchAdjustment(adjustmentId, approverId, remarks, substituteEmployeeId);
    }

    // Reject an adjustment batch (or single record)
    static async rejectBatchAdjustment(batchIdentifier, approverId, remarks) {
        const { batchId, rows: adjRows } = await this._resolveBatchRows(pool, batchIdentifier);
        if (!adjRows.length) throw new Error('Adjustment not found');

        const representative = adjRows.find(r => r.status === 'Pending') || adjRows[0];
        const currentLevel = representative.current_level || 1;

        // Check designated active level approver
        const expectedApproverId = (currentLevel === 1) ? representative.approver_1_id : representative.approver_2_id;
        if (approverId !== expectedApproverId) {
            const [roleRows] = await pool.execute(
                `SELECT r.role FROM employee e 
                 JOIN app_role r ON e.role_id = r.role_id 
                 WHERE e.employee_id = ? AND e.active = 1`,
                [approverId]
            );
            const role = roleRows[0]?.role?.toLowerCase();
            const isAdminOverride = ['super_admin', 'admin', 'principal'].includes(role);
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
                     WHERE batch_id = ? AND status = 'Pending'`;
            params = [approverId, remarks || '', batchId];
        } else {
            query = `UPDATE attendance_regularization 
                     SET status = 'Rejected', approved_by = ?, approved_on = NOW(),
                         approver_2_remarks = ?, approver_2_action_on = NOW()
                     WHERE batch_id = ? AND status = 'Pending'`;
            params = [approverId, remarks || '', batchId];
        }

        const [rows] = await pool.execute(query, params);
        return { affected_rows: rows.affectedRows };
    }

    // Reject an adjustment (delegates to rejectBatchAdjustment)
    static async rejectAdjustment(adjustmentId, approverId, remarks) {
        return this.rejectBatchAdjustment(adjustmentId, approverId, remarks);
    }

    // Delete a pending adjustment batch (or single record)
    static async deleteBatchAdjustment(batchIdentifier, employeeId) {
        const { batchId, rows: adjRows } = await this._resolveBatchRows(pool, batchIdentifier);
        const pendingUserRows = adjRows.filter(r => r.status === 'Pending' && r.employee_id === Number(employeeId));
        if (!pendingUserRows.length) {
            return { affected_rows: 0 };
        }
        const [rows] = await pool.execute(
            `DELETE FROM attendance_regularization 
             WHERE batch_id = ? AND employee_id = ? AND status = 'Pending'`,
            [batchId, employeeId]
        );
        return { affected_rows: rows.affectedRows };
    }

    // Delete a pending adjustment (delegates to deleteBatchAdjustment)
    static async deleteAdjustment(adjustmentId, employeeId) {
        return this.deleteBatchAdjustment(adjustmentId, employeeId);
    }

    // Get adjustment history for an employee with filters (aggregated by batch)
    static async getEmployeeAdjustments(employeeId, month = null, year = null) {
        let query = `
            SELECT 
                MIN(aj.id) AS id,
                aj.batch_id,
                aj.employee_id,
                aj.request_type,
                MIN(aj.date) AS date,
                COALESCE(ANY_VALUE(aj.range_from_date), MIN(aj.date)) AS from_date,
                COALESCE(ANY_VALUE(aj.range_to_date), MAX(aj.date)) AS to_date,
                COUNT(*) AS total_days,
                COALESCE(ANY_VALUE(aj.range_calendar_days), DATEDIFF(MAX(aj.date), MIN(aj.date)) + 1) AS calendar_days,
                ANY_VALUE(aj.range_skipped_summary) AS range_skipped_summary,
                MIN(aj.requested_in_time) AS requested_in_time,
                MAX(aj.requested_out_time) AS requested_out_time,
                ANY_VALUE(aj.regularization_shift_type) AS regularization_shift_type,
                ANY_VALUE(aj.reason) AS reason,
                ANY_VALUE(aj.status) AS status,
                MIN(aj.created_on) AS created_on,
                ANY_VALUE(aj.approved_by) AS approved_by,
                ANY_VALUE(aj.approved_on) AS approved_on,
                ANY_VALUE(aj.substitute_employee_id) AS substitute_employee_id,
                ANY_VALUE(aj.approver_1_id) AS approver_1_id,
                ANY_VALUE(aj.approver_2_id) AS approver_2_id,
                ANY_VALUE(aj.current_level) AS current_level,
                ANY_VALUE(aj.approver_1_remarks) AS approver_1_remarks,
                ANY_VALUE(aj.approver_1_action_on) AS approver_1_action_on,
                ANY_VALUE(aj.approver_2_remarks) AS approver_2_remarks,
                ANY_VALUE(aj.approver_2_action_on) AS approver_2_action_on,
                ANY_VALUE(aj.applied_by_id) AS applied_by_id,
                ANY_VALUE(aj.is_proxy) AS is_proxy,
                ANY_VALUE(e.employee_name) AS approver_name,
                ANY_VALUE(ea1.employee_name) AS approver_1_name,
                ANY_VALUE(ea1.employee_code) AS approver_1_code,
                ANY_VALUE(ea2.employee_name) AS approver_2_name,
                ANY_VALUE(ea2.employee_code) AS approver_2_code,
                MIN(ad.first_in_time) AS actual_in_time,
                MAX(ad.last_out_time) AS actual_out_time,
                GROUP_CONCAT(DISTINCT ad.status SEPARATOR ' / ') AS actual_status,
                ANY_VALUE(sub.employee_name) AS substitute_name,
                ANY_VALUE(sub.employee_code) AS substitute_code,
                ANY_VALUE(ap_proxy.employee_name) AS applied_by_name,
                ANY_VALUE(ap_proxy.employee_code) AS applied_by_code
            FROM attendance_regularization aj 
            LEFT JOIN employee e ON aj.approved_by = e.employee_id 
            LEFT JOIN employee ea1 ON ea1.employee_id = aj.approver_1_id
            LEFT JOIN employee ea2 ON ea2.employee_id = aj.approver_2_id
            LEFT JOIN employee sub ON sub.employee_id = aj.substitute_employee_id
            LEFT JOIN employee ap_proxy ON ap_proxy.employee_id = aj.applied_by_id
            LEFT JOIN (
                SELECT employee_id, date, 
                       MIN(first_in_time) AS first_in_time, 
                       MAX(last_out_time) AS last_out_time,
                       GROUP_CONCAT(status ORDER BY shift_type SEPARATOR ' / ') AS status
                FROM attendance
                GROUP BY employee_id, date
            ) ad ON ad.employee_id = aj.employee_id AND ad.date = aj.date
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

        query += " GROUP BY aj.batch_id, aj.employee_id, aj.request_type ORDER BY MIN(aj.created_on) DESC";

        const [rows] = await pool.execute(query, params);
        return rows;
    }

    // Get a specific adjustment by ID or batch_id
    static async getEmployeeAdjustmentsById(identifier) {
        const { rows } = await this._resolveBatchRows(pool, identifier);
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
     * Paginated approval queue — supports status filter and aggregates batches into single cards.
     * isAdmin = true  → all records
     * isAdmin = false → manager sees active designated approvals (when Pending) or subordinates/assigned (when not Pending)
     */
    static async getApprovalQueue({ isAdmin, managerId, status = 'Pending', page = 1, limit = 10 }) {
        const offset = (page - 1) * limit;
        const statusFilter = (status && status !== 'All') ? status : null;

        let dataQuery, countQuery, params = [], countParams = [];

        if (isAdmin) {
            dataQuery = `
                SELECT 
                    MIN(aj.id) AS id,
                    aj.batch_id,
                    aj.employee_id,
                    aj.request_type,
                    MIN(aj.date) AS date,
                    COALESCE(ANY_VALUE(aj.range_from_date), MIN(aj.date)) AS from_date,
                    COALESCE(ANY_VALUE(aj.range_to_date), MAX(aj.date)) AS to_date,
                    COUNT(*) AS total_days,
                    COALESCE(ANY_VALUE(aj.range_calendar_days), DATEDIFF(MAX(aj.date), MIN(aj.date)) + 1) AS calendar_days,
                    ANY_VALUE(aj.range_skipped_summary) AS range_skipped_summary,
                    MIN(aj.requested_in_time) AS requested_in_time,
                    MAX(aj.requested_out_time) AS requested_out_time,
                    ANY_VALUE(aj.regularization_shift_type) AS regularization_shift_type,
                    ANY_VALUE(aj.reason) AS reason,
                    ANY_VALUE(aj.status) AS status,
                    MIN(aj.created_on) AS created_on,
                    ANY_VALUE(aj.approved_by) AS approved_by,
                    ANY_VALUE(aj.approved_on) AS approved_on,
                    ANY_VALUE(aj.substitute_employee_id) AS substitute_employee_id,
                    ANY_VALUE(aj.approver_1_id) AS approver_1_id,
                    ANY_VALUE(aj.approver_2_id) AS approver_2_id,
                    ANY_VALUE(aj.current_level) AS current_level,
                    ANY_VALUE(aj.approver_1_remarks) AS approver_1_remarks,
                    ANY_VALUE(aj.approver_1_action_on) AS approver_1_action_on,
                    ANY_VALUE(aj.approver_2_remarks) AS approver_2_remarks,
                    ANY_VALUE(aj.approver_2_action_on) AS approver_2_action_on,
                    ANY_VALUE(aj.applied_by_id) AS applied_by_id,
                    ANY_VALUE(aj.is_proxy) AS is_proxy,
                    ANY_VALUE(e.employee_name) AS employee_name,
                    ANY_VALUE(e.employee_code) AS employee_code,
                    ANY_VALUE(d.departmentname) AS department_name,
                    ANY_VALUE(des.designation) AS employee_designation,
                    ANY_VALUE(ap.employee_name) AS approver_name,
                    ANY_VALUE(ea1.employee_name) AS approver_1_name,
                    ANY_VALUE(ea1.employee_code) AS approver_1_code,
                    ANY_VALUE(ea2.employee_name) AS approver_2_name,
                    ANY_VALUE(ea2.employee_code) AS approver_2_code,
                    ANY_VALUE(sub.employee_name) AS substitute_name,
                    ANY_VALUE(sub.employee_code) AS substitute_code,
                    ANY_VALUE(ap_proxy.employee_name) AS applied_by_name,
                    ANY_VALUE(ap_proxy.employee_code) AS applied_by_code,
                    MIN(ad.first_in_time) AS actual_in_time,
                    MAX(ad.last_out_time) AS actual_out_time,
                    GROUP_CONCAT(DISTINCT ad.status SEPARATOR ' / ') AS actual_status
                FROM attendance_regularization aj
                JOIN employee e ON aj.employee_id = e.employee_id
                LEFT JOIN department d ON e.department_id = d.department_id
                LEFT JOIN designation des ON e.designation_id = des.designation_id
                LEFT JOIN employee ap  ON ap.employee_id  = aj.approved_by
                LEFT JOIN employee ea1 ON ea1.employee_id = aj.approver_1_id
                LEFT JOIN employee ea2 ON ea2.employee_id = aj.approver_2_id
                LEFT JOIN employee sub ON sub.employee_id = aj.substitute_employee_id
                LEFT JOIN employee ap_proxy ON ap_proxy.employee_id = aj.applied_by_id
                LEFT JOIN (
                    SELECT employee_id, date, 
                           MIN(first_in_time) AS first_in_time, 
                           MAX(last_out_time) AS last_out_time,
                           GROUP_CONCAT(status ORDER BY shift_type SEPARATOR ' / ') AS status
                    FROM attendance
                    GROUP BY employee_id, date
                ) ad ON ad.employee_id = aj.employee_id AND ad.date = aj.date
                WHERE 1=1
                ${statusFilter ? 'AND aj.status = ?' : ""}
                GROUP BY aj.batch_id, aj.employee_id, aj.request_type
                ORDER BY MIN(aj.created_on) DESC
                LIMIT ? OFFSET ?`;

            countQuery = `
                SELECT COUNT(DISTINCT aj.batch_id) AS total FROM attendance_regularization aj
                WHERE 1=1 ${statusFilter ? 'AND aj.status = ?' : ''}`;

            if (statusFilter) { params.push(statusFilter); countParams.push(statusFilter); }
            params.push(parseInt(limit), parseInt(offset));
        } else {
            // For non-admin managers:
            // When status is Pending: STRICTLY match the designated active approver at that level.
            // Level 1: current_level = 1 AND approver_1_id = managerId
            // Level 2: current_level = 2 AND approver_2_id = managerId
            // This prevents Level 2 approvers from seeing Level 1 requests before Level 1 approves.
            if (statusFilter === 'Pending') {
                dataQuery = `
                    SELECT 
                        MIN(aj.id) AS id,
                        aj.batch_id,
                        aj.employee_id,
                        aj.request_type,
                        MIN(aj.date) AS date,
                        COALESCE(ANY_VALUE(aj.range_from_date), MIN(aj.date)) AS from_date,
                        COALESCE(ANY_VALUE(aj.range_to_date), MAX(aj.date)) AS to_date,
                        COUNT(*) AS total_days,
                        COALESCE(ANY_VALUE(aj.range_calendar_days), DATEDIFF(MAX(aj.date), MIN(aj.date)) + 1) AS calendar_days,
                        ANY_VALUE(aj.range_skipped_summary) AS range_skipped_summary,
                        MIN(aj.requested_in_time) AS requested_in_time,
                        MAX(aj.requested_out_time) AS requested_out_time,
                        ANY_VALUE(aj.regularization_shift_type) AS regularization_shift_type,
                        ANY_VALUE(aj.reason) AS reason,
                        ANY_VALUE(aj.status) AS status,
                        MIN(aj.created_on) AS created_on,
                        ANY_VALUE(aj.approved_by) AS approved_by,
                        ANY_VALUE(aj.approved_on) AS approved_on,
                        ANY_VALUE(aj.substitute_employee_id) AS substitute_employee_id,
                        ANY_VALUE(aj.approver_1_id) AS approver_1_id,
                        ANY_VALUE(aj.approver_2_id) AS approver_2_id,
                        ANY_VALUE(aj.current_level) AS current_level,
                        ANY_VALUE(aj.approver_1_remarks) AS approver_1_remarks,
                        ANY_VALUE(aj.approver_1_action_on) AS approver_1_action_on,
                        ANY_VALUE(aj.approver_2_remarks) AS approver_2_remarks,
                        ANY_VALUE(aj.approver_2_action_on) AS approver_2_action_on,
                        ANY_VALUE(aj.applied_by_id) AS applied_by_id,
                        ANY_VALUE(aj.is_proxy) AS is_proxy,
                        ANY_VALUE(e.employee_name) AS employee_name,
                        ANY_VALUE(e.employee_code) AS employee_code,
                        ANY_VALUE(d.departmentname) AS department_name,
                        ANY_VALUE(des.designation) AS employee_designation,
                        ANY_VALUE(ap.employee_name) AS approver_name,
                        ANY_VALUE(ea1.employee_name) AS approver_1_name,
                        ANY_VALUE(ea1.employee_code) AS approver_1_code,
                        ANY_VALUE(ea2.employee_name) AS approver_2_name,
                        ANY_VALUE(ea2.employee_code) AS approver_2_code,
                        ANY_VALUE(sub.employee_name) AS substitute_name,
                        ANY_VALUE(sub.employee_code) AS substitute_code,
                        ANY_VALUE(ap_proxy.employee_name) AS applied_by_name,
                        ANY_VALUE(ap_proxy.employee_code) AS applied_by_code,
                        MIN(ad.first_in_time) AS actual_in_time,
                        MAX(ad.last_out_time) AS actual_out_time,
                        GROUP_CONCAT(DISTINCT ad.status SEPARATOR ' / ') AS actual_status
                    FROM attendance_regularization aj
                    JOIN employee e ON aj.employee_id = e.employee_id
                    LEFT JOIN department d ON e.department_id = d.department_id
                    LEFT JOIN designation des ON e.designation_id = des.designation_id
                    LEFT JOIN employee ap  ON ap.employee_id  = aj.approved_by
                    LEFT JOIN employee ea1 ON ea1.employee_id = aj.approver_1_id
                    LEFT JOIN employee ea2 ON ea2.employee_id = aj.approver_2_id
                    LEFT JOIN employee sub ON sub.employee_id = aj.substitute_employee_id
                    LEFT JOIN employee ap_proxy ON ap_proxy.employee_id = aj.applied_by_id
                    LEFT JOIN (
                        SELECT employee_id, date, 
                               MIN(first_in_time) AS first_in_time, 
                               MAX(last_out_time) AS last_out_time,
                               GROUP_CONCAT(status ORDER BY shift_type SEPARATOR ' / ') AS status
                        FROM attendance
                        GROUP BY employee_id, date
                    ) ad ON ad.employee_id = aj.employee_id AND ad.date = aj.date
                    WHERE aj.status = 'Pending'
                      AND ((aj.current_level = 1 AND aj.approver_1_id = ?)
                        OR (aj.current_level = 2 AND aj.approver_2_id = ?))
                    GROUP BY aj.batch_id, aj.employee_id, aj.request_type
                    ORDER BY MIN(aj.created_on) DESC
                    LIMIT ? OFFSET ?`;

                countQuery = `
                    SELECT COUNT(DISTINCT aj.batch_id) AS total FROM attendance_regularization aj
                    WHERE aj.status = 'Pending'
                      AND ((aj.current_level = 1 AND aj.approver_1_id = ?)
                        OR (aj.current_level = 2 AND aj.approver_2_id = ?))`;

                params = [managerId, managerId, parseInt(limit), parseInt(offset)];
                countParams = [managerId, managerId];
            } else {
                // When not Pending (All, Approved, Rejected):
                // Manager can see adjustments of their subordinates OR where they acted as approver 1 or 2.
                dataQuery = `
                    WITH RECURSIVE subordinates AS (
                        SELECT employee_id FROM employee WHERE reporting_manager_id = ?
                        UNION ALL
                        SELECT e.employee_id FROM employee e
                        INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
                    )
                    SELECT 
                        MIN(aj.id) AS id,
                        aj.batch_id,
                        aj.employee_id,
                        aj.request_type,
                        MIN(aj.date) AS date,
                        COALESCE(ANY_VALUE(aj.range_from_date), MIN(aj.date)) AS from_date,
                        COALESCE(ANY_VALUE(aj.range_to_date), MAX(aj.date)) AS to_date,
                        COUNT(*) AS total_days,
                        COALESCE(ANY_VALUE(aj.range_calendar_days), DATEDIFF(MAX(aj.date), MIN(aj.date)) + 1) AS calendar_days,
                        ANY_VALUE(aj.range_skipped_summary) AS range_skipped_summary,
                        MIN(aj.requested_in_time) AS requested_in_time,
                        MAX(aj.requested_out_time) AS requested_out_time,
                        ANY_VALUE(aj.regularization_shift_type) AS regularization_shift_type,
                        ANY_VALUE(aj.reason) AS reason,
                        ANY_VALUE(aj.status) AS status,
                        MIN(aj.created_on) AS created_on,
                        ANY_VALUE(aj.approved_by) AS approved_by,
                        ANY_VALUE(aj.approved_on) AS approved_on,
                        ANY_VALUE(aj.substitute_employee_id) AS substitute_employee_id,
                        ANY_VALUE(aj.approver_1_id) AS approver_1_id,
                        ANY_VALUE(aj.approver_2_id) AS approver_2_id,
                        ANY_VALUE(aj.current_level) AS current_level,
                        ANY_VALUE(aj.approver_1_remarks) AS approver_1_remarks,
                        ANY_VALUE(aj.approver_1_action_on) AS approver_1_action_on,
                        ANY_VALUE(aj.approver_2_remarks) AS approver_2_remarks,
                        ANY_VALUE(aj.approver_2_action_on) AS approver_2_action_on,
                        ANY_VALUE(aj.applied_by_id) AS applied_by_id,
                        ANY_VALUE(aj.is_proxy) AS is_proxy,
                        ANY_VALUE(e.employee_name) AS employee_name,
                        ANY_VALUE(e.employee_code) AS employee_code,
                        ANY_VALUE(d.departmentname) AS department_name,
                        ANY_VALUE(des.designation) AS employee_designation,
                        ANY_VALUE(ap.employee_name) AS approver_name,
                        ANY_VALUE(ea1.employee_name) AS approver_1_name,
                        ANY_VALUE(ea1.employee_code) AS approver_1_code,
                        ANY_VALUE(ea2.employee_name) AS approver_2_name,
                        ANY_VALUE(ea2.employee_code) AS approver_2_code,
                        ANY_VALUE(sub.employee_name) AS substitute_name,
                        ANY_VALUE(sub.employee_code) AS substitute_code,
                        ANY_VALUE(ap_proxy.employee_name) AS applied_by_name,
                        ANY_VALUE(ap_proxy.employee_code) AS applied_by_code,
                        MIN(ad.first_in_time) AS actual_in_time,
                        MAX(ad.last_out_time) AS actual_out_time,
                        GROUP_CONCAT(DISTINCT ad.status SEPARATOR ' / ') AS actual_status
                    FROM attendance_regularization aj
                    JOIN employee e ON aj.employee_id = e.employee_id
                    LEFT JOIN department d ON e.department_id = d.department_id
                    LEFT JOIN designation des ON e.designation_id = des.designation_id
                    LEFT JOIN employee ap  ON ap.employee_id  = aj.approved_by
                    LEFT JOIN employee ea1 ON ea1.employee_id = aj.approver_1_id
                    LEFT JOIN employee ea2 ON ea2.employee_id = aj.approver_2_id
                    LEFT JOIN employee sub ON sub.employee_id = aj.substitute_employee_id
                    LEFT JOIN employee ap_proxy ON ap_proxy.employee_id = aj.applied_by_id
                    LEFT JOIN (
                        SELECT employee_id, date, 
                               MIN(first_in_time) AS first_in_time, 
                               MAX(last_out_time) AS last_out_time,
                               GROUP_CONCAT(status ORDER BY shift_type SEPARATOR ' / ') AS status
                        FROM attendance
                        GROUP BY employee_id, date
                    ) ad ON ad.employee_id = aj.employee_id AND ad.date = aj.date
                    WHERE (aj.employee_id IN (SELECT employee_id FROM subordinates)
                       OR aj.approver_1_id = ?
                       OR aj.approver_2_id = ?)
                    ${statusFilter ? 'AND aj.status = ?' : ''}
                    GROUP BY aj.batch_id, aj.employee_id, aj.request_type
                    ORDER BY MIN(aj.created_on) DESC
                    LIMIT ? OFFSET ?`;

                countQuery = `
                    WITH RECURSIVE subordinates AS (
                        SELECT employee_id FROM employee WHERE reporting_manager_id = ?
                        UNION ALL
                        SELECT e.employee_id FROM employee e
                        INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
                    )
                    SELECT COUNT(DISTINCT aj.batch_id) AS total FROM attendance_regularization aj
                    WHERE (aj.employee_id IN (SELECT employee_id FROM subordinates)
                       OR aj.approver_1_id = ?
                       OR aj.approver_2_id = ?)
                    ${statusFilter ? 'AND aj.status = ?' : ''}`;

                params = [managerId, managerId, managerId];
                countParams = [managerId, managerId, managerId];
                if (statusFilter) {
                    params.push(statusFilter);
                    countParams.push(statusFilter);
                }
                params.push(parseInt(limit), parseInt(offset));
            }
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
                    `DELETE FROM attendance 
                     WHERE employee_id = ? AND date = ? AND status = 'Leave'`,
                    [employeeId, d]
                );

                if (result.affectedRows > 0) {
                    // 2. Try to re-process logs for this date.
                    // If logs exist, it will recreate a 'Present' record.
                    try {
                        await conn.execute('CALL sp_process_attendance_shiftwise(?)', [d]);
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
                `DELETE FROM attendance WHERE employee_id = ? AND date = ?`,
                [employee_id, date]
            );

            await conn.execute(
                `INSERT INTO attendance (
                    employee_id, date, status, first_in_time, last_out_time, worked_mins,
                    is_late, is_early_leaving, deduction_days, shift_type,
                    created_on
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'FullDay', NOW())`,
                [
                    employee_id, date, status,
                    first_in_time || null, last_out_time || null, worked_mins,
                    is_late || 0, is_early_leaving || 0, deduction_days || 0.00
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

            const batchId = crypto.randomUUID();
            const [result] = await conn.execute(
                `INSERT INTO attendance_regularization 
                (batch_id, employee_id, request_type, date, requested_in_time, requested_out_time, regularization_shift_type, reason, status, created_on) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Pending', NOW())`,
                [batchId, employee_id, type, targetDate, requested_in_time || null, requested_out_time || null, requestedShift, reason]
            );

            const adjustmentId = result.insertId;

            await conn.commit();

            const approveRes = await this.approveAdjustment(adjustmentId, approverId, 'Super Admin Direct Bypass Approval');

            return { success: true, adjustment_id: adjustmentId, batch_id: batchId, ...approveRes };
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }
}

module.exports = AttendanceModel;

