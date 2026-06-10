const pool = require('../config/db');
const LeaveRequestModel = require('./leaveRequestModel');

class LeaveModel {
    /**
     * Get leave balance for an employee.
     * Delegates to LeaveRequestModel which has the verified balance engine.
     */
    static async getBalance(employeeId) {
        return LeaveRequestModel.getLeaveBalance(employeeId);
    }

    /**
     * Get leave types available for an employee based on their active policy.
     */
    static async getAvailableTypes(employeeId) {
        const balance = await LeaveRequestModel.getLeaveBalance(employeeId);
        return balance.map(b => ({
            leave_type: b.leaveType,
            available: b.available,
            strategy: b.strategy
        }));
    }

    /**
     * Apply for a new leave.
     * Supports substitute_employee_id and auto-resolves approvers from config.
     * SP: sp_apply_leave(employee_id, leave_type, start_date, end_date,
     *   total_days, reason, attachment, substitute_id, approver_1_id, approver_2_id)
     */
    static async apply(data) {
        const {
            employee_id,
            leave_type,
            start_date,
            end_date,
            leave_half_type,
            reason,
            attachment_path,
            total_days,
            substitute_employee_id
        } = data;

        const halfType = leave_half_type || 'FullDay';
        const actualDays = halfType !== 'FullDay' ? 0.5 : (total_days || 0);

        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            // Resolve approver config from employee_approver_configs
            const [configRows] = await conn.execute(
                `SELECT
                    COALESCE(eac.approver_1_id, e.reporting_manager_id,
                        (SELECT e2.employee_id FROM employee e2
                         JOIN app_role r2 ON e2.role_id = r2.role_id
                         WHERE r2.role IN ('Principal','principal') AND e2.active = 1 LIMIT 1)
                    ) AS approver_1_id,
                    eac.approver_2_id
                 FROM employee e
                 LEFT JOIN employee_approver_configs eac
                   ON eac.employee_id = e.employee_id AND eac.request_type = 'LEAVE'
                 WHERE e.employee_id = ?`,
                [employee_id]
            );

            const approver1 = configRows[0]?.approver_1_id || null;
            const approver2 = configRows[0]?.approver_2_id || null;

            const [rows] = await conn.execute(
                'CALL sp_apply_leave(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [
                    employee_id,
                    leave_type,
                    start_date,
                    end_date,
                    actualDays,
                    reason,
                    attachment_path || null,
                    substitute_employee_id || null,
                    approver1,
                    approver2
                ]
            );

            const result = rows[0][0];

            // Safety net for half-days total_days
            if (result && result.leave_request_id && (!result.total_days || result.total_days == 0)) {
                if (halfType !== 'FullDay') {
                    await conn.execute(
                        'UPDATE leave_requests SET total_days = 0.5 WHERE leave_request_id = ?',
                        [result.leave_request_id]
                    );
                    result.total_days = 0.5;
                } else if (total_days > 0) {
                    await conn.execute(
                        'UPDATE leave_requests SET total_days = ? WHERE leave_request_id = ?',
                        [total_days, result.leave_request_id]
                    );
                    result.total_days = total_days;
                }
            }

            await conn.commit();
            return result;
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }

    /**
     * Get employee's own leave requests — includes approver names and substitute.
     */
    static async getMyRequests(employeeId) {
        const [rows] = await pool.execute(
            `SELECT
                lr.*,
                a1.employee_name AS approver_1_name,
                a2.employee_name AS approver_2_name,
                sub.employee_name AS substitute_name
             FROM leave_requests lr
             LEFT JOIN employee a1 ON a1.employee_id = lr.approver_1_id
             LEFT JOIN employee a2 ON a2.employee_id = lr.approver_2_id
             LEFT JOIN employee sub ON sub.employee_id = lr.substitute_employee_id
             WHERE lr.employee_id = ?
             ORDER BY lr.applied_on DESC`,
            [employeeId]
        );
        return rows;
    }

    /**
     * Get requests pending approval for the logged-in approver.
     * managerId = null  → Admin/Principal view (all requests)
     * managerId = <id>  → Approver view: only L1 queue (approver_1_id=me, level=1)
     *                     OR L2 queue (approver_2_id=me, level=2)
     */
    static async getApprovals(managerId, status, page = 1, limit = 10) {
        let sql = `
            SELECT
                lr.*,
                e.employee_name,
                e.employee_code,
                des.designation AS employee_designation,
                d.departmentname AS department_name,
                a1.employee_name AS approver_1_name,
                a2.employee_name AS approver_2_name,
                sub.employee_name AS substitute_name
            FROM leave_requests lr
            JOIN employee e ON lr.employee_id = e.employee_id
            LEFT JOIN department d ON e.department_id = d.department_id
            LEFT JOIN designation des ON e.designation_id = des.designation_id
            LEFT JOIN employee a1 ON a1.employee_id = lr.approver_1_id
            LEFT JOIN employee a2 ON a2.employee_id = lr.approver_2_id
            LEFT JOIN employee sub ON sub.employee_id = lr.substitute_employee_id
            WHERE 1=1
        `;
        const params = [];

        if (managerId) {
            if (!status || status === 'Pending') {
                sql += ` AND (
                    (lr.approver_1_id = ? AND lr.current_level = 1) OR
                    (lr.approver_2_id = ? AND lr.current_level = 2)
                )`;
                params.push(managerId, managerId);
            } else {
                sql += ` AND (
                    lr.approver_1_id = ? OR
                    lr.approver_2_id = ?
                )`;
                params.push(managerId, managerId);
            }
        }

        if (status && status !== 'All') {
            sql += ' AND lr.status = ?';
            params.push(status);
        }

        sql += ' ORDER BY lr.applied_on DESC';

        const offset = (page - 1) * limit;
        sql += ' LIMIT ? OFFSET ?';
        params.push(parseInt(limit), parseInt(offset));

        const [rows] = await pool.query(sql, params);
        return rows;
    }

    static async getApprovalsCount(managerId, status) {
        let sql = `
            SELECT COUNT(*) AS total
            FROM leave_requests lr
            JOIN employee e ON lr.employee_id = e.employee_id
            WHERE 1=1
        `;
        const params = [];

        if (managerId) {
            if (!status || status === 'Pending') {
                sql += ` AND (
                    (lr.approver_1_id = ? AND lr.current_level = 1) OR
                    (lr.approver_2_id = ? AND lr.current_level = 2)
                )`;
                params.push(managerId, managerId);
            } else {
                sql += ` AND (
                    lr.approver_1_id = ? OR
                    lr.approver_2_id = ?
                )`;
                params.push(managerId, managerId);
            }
        }

        if (status && status !== 'All') {
            sql += ' AND lr.status = ?';
            params.push(status);
        }

        const [rows] = await pool.execute(sql, params);
        return rows[0]?.total || 0;
    }

    /**
     * Approve or Reject a leave request — 2-level aware.
     * Implemented directly in Node.js to avoid the broken sp_approve_leave SP
     * which referenced a non-existent `is_leave_type` column.
     *
     * Returns { leave_request_id, result_status, next_level }
     *   result_status = 'Pending' + next_level = 2 → advanced to Level 2
     *   result_status = 'Approved' | 'Rejected'   → final decision
     */
    static async action(requestId, status, approverId, remarks, substituteId) {
        if (!['Approved', 'Rejected'].includes(status)) {
            throw new Error('Invalid status: must be Approved or Rejected');
        }

        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            // 1. Fetch the leave request (with lock)
            const [lrRows] = await conn.execute(
                `SELECT lr.*, e.employee_id AS emp_id
                 FROM leave_requests lr
                 JOIN employee e ON e.employee_id = lr.employee_id
                 WHERE lr.leave_request_id = ?
                 FOR UPDATE`,
                [requestId]
            );

            if (!lrRows.length) {
                throw new Error('Leave request not found');
            }

            const lr = lrRows[0];

            if (lr.status !== 'Pending') {
                throw new Error('Request is already actioned or does not exist');
            }

            const {
                employee_id: empId,
                start_date: startDate,
                end_date: endDate,
                leave_type: leaveType,
                leave_half_type: leaveHalf,
                approver_1_id: approver1,
                approver_2_id: approver2,
                current_level: currentLevel,
                total_days: totalDays
            } = lr;

            const halfType = leaveHalf || 'FullDay';

            // 2. Override substitute if provided by approver
            if (substituteId) {
                await conn.execute(
                    'UPDATE leave_requests SET substitute_employee_id = ? WHERE leave_request_id = ?',
                    [substituteId, requestId]
                );
            }

            // ── REJECTION at any level ───────────────────────────────────────
            if (status === 'Rejected') {
                const col1Remarks = currentLevel === 1 ? remarks : lr.approver_1_remarks;
                const col2Remarks = currentLevel === 2 ? remarks : lr.approver_2_remarks;
                await conn.execute(
                    `UPDATE leave_requests SET
                        status             = 'Rejected',
                        approved_by_id     = ?,
                        approved_on        = NOW(),
                        approver_1_remarks = ?,
                        approver_2_remarks = ?
                     WHERE leave_request_id = ?`,
                    [approverId, col1Remarks || null, col2Remarks || null, requestId]
                );
                await conn.commit();
                return { leave_request_id: requestId, result_status: 'Rejected', next_level: null };
            }

            // ── APPROVAL AT LEVEL 1 ──────────────────────────────────────────
            if (status === 'Approved' && currentLevel === 1) {
                if (approver2) {
                    // Advance to Level 2 — no attendance update yet
                    await conn.execute(
                        `UPDATE leave_requests SET
                            current_level        = 2,
                            approver_1_remarks   = ?,
                            approver_1_action_on = NOW()
                         WHERE leave_request_id = ?`,
                        [remarks || null, requestId]
                    );
                    await conn.commit();
                    return { leave_request_id: requestId, result_status: 'Pending', next_level: 2 };
                }
                // Single-level: mark Approved
                await conn.execute(
                    `UPDATE leave_requests SET
                        status               = 'Approved',
                        approved_by_id       = ?,
                        approved_on          = NOW(),
                        approver_1_remarks   = ?,
                        approver_1_action_on = NOW()
                     WHERE leave_request_id = ?`,
                    [approverId, remarks || null, requestId]
                );
            }

            // ── APPROVAL AT LEVEL 2 (final) ──────────────────────────────────
            if (status === 'Approved' && currentLevel === 2) {
                await conn.execute(
                    `UPDATE leave_requests SET
                        status               = 'Approved',
                        approved_by_id       = ?,
                        approved_on          = NOW(),
                        approver_2_remarks   = ?,
                        approver_2_action_on = NOW()
                     WHERE leave_request_id = ?`,
                    [approverId, remarks || null, requestId]
                );
            }

            // ── Phase 1: Conflict validation ─────────────────────────────────
            const msPerDay = 24 * 60 * 60 * 1000;
            const start = new Date(startDate);
            const end = new Date(endDate);

            for (let d = new Date(start); d <= end; d = new Date(d.getTime() + msPerDay)) {
                const dateStr = d.toISOString().split('T')[0];

                const [adRows] = await conn.execute(
                    `SELECT regularization_shift_type, is_leave, leave_shift_type, status
                     FROM attendance_daily
                     WHERE employee_id = ? AND date = ?
                     LIMIT 1`,
                    [empId, dateStr]
                );

                if (!adRows.length) continue;
                const ad = adRows[0];

                // Skip weekends / holidays
                if (['WeekEnd', 'Public Holiday', 'Exceptional Holiday'].includes(ad.status)) continue;

                // Check holiday_master
                const [hmRows] = await conn.execute(
                    `SELECT 1 FROM holiday_master
                     WHERE ? BETWEEN holiday_start_date AND holiday_end_date
                       AND is_active = 1 AND employee_id IN (?, -1)
                     LIMIT 1`,
                    [dateStr, empId]
                );
                if (hmRows.length) continue;

                // Conflict: regularized / on-duty
                if (ad.regularization_shift_type) {
                    if (ad.regularization_shift_type === 'FullDay') {
                        throw new Error('Conflict: One or more days are already fully regularized/on-duty');
                    }
                    if (ad.regularization_shift_type === halfType && halfType !== 'FullDay') {
                        throw new Error('Conflict: This half of the day is already regularized/on-duty');
                    }
                    if (halfType === 'FullDay' && ad.regularization_shift_type !== 'FullDay') {
                        throw new Error('Conflict: A part of this day is already regularized/on-duty.');
                    }
                }

                // Conflict: another approved leave
                if (ad.is_leave) {
                    if (ad.leave_shift_type === 'FullDay') {
                        throw new Error('Conflict: One or more days already have an approved leave');
                    }
                    if (ad.leave_shift_type === halfType && halfType !== 'FullDay') {
                        throw new Error('Conflict: An approved leave already exists for this half-day');
                    }
                    if (halfType === 'FullDay' && ad.leave_shift_type !== 'FullDay') {
                        throw new Error('Conflict: A part of this day already has an approved leave.');
                    }
                }
            }

            // ── Phase 2: Deduct leave balance ────────────────────────────────
            await conn.execute(
                `INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
                 VALUES (?, ?, DATE_FORMAT(?, '%m-%Y'), 0, 0, ?)
                 ON DUPLICATE KEY UPDATE leaves_taken = leaves_taken + ?`,
                [empId, leaveType, startDate, totalDays, totalDays]
            );

            // ── Phase 3: Update attendance_daily ─────────────────────────────
            for (let d = new Date(start); d <= end; d = new Date(d.getTime() + msPerDay)) {
                const dateStr = d.toISOString().split('T')[0];

                const [adRows] = await conn.execute(
                    `SELECT first_in_time, last_out_time, worked_mins,
                            shift_type, status,
                            regularization_shift_type, onduty_shift_type,
                            is_leave, leave_shift_type
                     FROM attendance_daily
                     WHERE employee_id = ? AND date = ?
                     LIMIT 1`,
                    [empId, dateStr]
                );

                // Skip weekends / holidays
                if (adRows.length && ['WeekEnd', 'Public Holiday', 'Exceptional Holiday'].includes(adRows[0].status)) continue;
                const [hmRows] = await conn.execute(
                    `SELECT 1 FROM holiday_master
                     WHERE ? BETWEEN holiday_start_date AND holiday_end_date
                       AND is_active = 1 AND employee_id IN (?, -1) LIMIT 1`,
                    [dateStr, empId]
                );
                if (hmRows.length) continue;

                const ad = adRows[0] || {};
                const curShift      = ad.shift_type;
                const regShift      = ad.regularization_shift_type;
                const odShift       = ad.onduty_shift_type;
                const isLeaveEx     = ad.is_leave;
                const leaveShiftEx  = ad.leave_shift_type;

                const firstHalf  = ['FirstHalf', 'FullDay'].includes(curShift) ||
                                   ['FirstHalf', 'FullDay'].includes(regShift) ||
                                   ['FirstHalf', 'FullDay'].includes(odShift) ||
                                   (isLeaveEx && ['FirstHalf', 'FullDay'].includes(leaveShiftEx)) ||
                                   ['FirstHalf', 'FullDay'].includes(halfType);

                const secondHalf = ['SecondHalf', 'FullDay'].includes(curShift) ||
                                   ['SecondHalf', 'FullDay'].includes(regShift) ||
                                   ['SecondHalf', 'FullDay'].includes(odShift) ||
                                   (isLeaveEx && ['SecondHalf', 'FullDay'].includes(leaveShiftEx)) ||
                                   ['SecondHalf', 'FullDay'].includes(halfType);

                const finalShift = (firstHalf && secondHalf) ? 'FullDay'
                                 : firstHalf                  ? 'FirstHalf'
                                 : secondHalf                 ? 'SecondHalf'
                                 : 'Absent';

                const finalDeduct = (!firstHalf && !secondHalf) ? 1.00
                                  : (firstHalf && secondHalf)   ? 0.00
                                  : 0.50;

                const finalStatus = (finalShift === 'FullDay' || curShift === 'FullDay') ? 'Present' : 'Leave';

                // Determine merged leave_shift_type
                let mergedLeaveShift = halfType;
                if (isLeaveEx && leaveShiftEx && leaveShiftEx !== halfType) {
                    mergedLeaveShift = 'FullDay'; // both halves covered
                }

                await conn.execute(
                    `INSERT INTO attendance_daily
                        (employee_id, date,
                         first_in_time, last_out_time, worked_mins,
                         shift_type, status,
                         is_late, late_minutes,
                         is_early_leaving, early_minutes,
                         overtime_minutes, deduction_days,
                         is_worked_on_holiday,
                         is_leave, leave_shift_type)
                     VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, ?, 0, 1, ?)
                     ON DUPLICATE KEY UPDATE
                        status           = VALUES(status),
                        deduction_days   = VALUES(deduction_days),
                        is_leave         = 1,
                        leave_shift_type = VALUES(leave_shift_type)`,
                    [
                        empId, dateStr,
                        ad.first_in_time || null,
                        ad.last_out_time  || null,
                        ad.worked_mins    || 0,
                        finalShift,
                        finalStatus,
                        finalDeduct,
                        mergedLeaveShift
                    ]
                );
            }

            await conn.commit();

            return {
                leave_request_id:     requestId,
                employee_id:          empId,
                start_date:           startDate,
                end_date:             endDate,
                leave_half_type:      halfType,
                result_status:        'Approved',
                next_level:           null,
                working_days_deducted: totalDays
            };

        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }

    /**
     * Cancel a leave request.
     */
    static async cancel(requestId, cancellerId) {
        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();

            // 1. Get the leave request
            const [lrRows] = await conn.execute(
                'SELECT * FROM leave_requests WHERE leave_request_id = ? FOR UPDATE',
                [requestId]
            );

            if (!lrRows.length) {
                throw new Error('Leave request not found');
            }

            const lr = lrRows[0];
            
            if (lr.status === 'Cancelled') {
                await conn.commit();
                return { success: true, message: 'Already cancelled' };
            }

            // 2. If it was already Approved, we must reverse the effects
            if (lr.status === 'Approved') {
                const totalDays = parseFloat(lr.total_working_days) || 0;
                
                // A. Refund the leave balance
                await conn.execute(
                    `UPDATE employee_leaves 
                     SET leaves_taken = GREATEST(0, leaves_taken - ?)
                     WHERE emp_id = ? AND leave_type = ? AND month_year = DATE_FORMAT(?, '%m-%Y')`,
                    [totalDays, lr.employee_id, lr.leave_type, lr.start_date]
                );

                // B. Revert attendance_daily
                const msPerDay = 24 * 60 * 60 * 1000;
                const start = new Date(lr.start_date);
                const end = new Date(lr.end_date);
                const halfType = lr.leave_half_type || 'FullDay';

                for (let d = new Date(start); d <= end; d = new Date(d.getTime() + msPerDay)) {
                    const dateStr = d.toISOString().split('T')[0];

                    const [adRows] = await conn.execute(
                        `SELECT * FROM attendance_daily WHERE employee_id = ? AND date = ? FOR UPDATE`,
                        [lr.employee_id, dateStr]
                    );

                    if (!adRows.length) continue;
                    const ad = adRows[0];

                    // Determine what remains after removing this leave
                    let newLeaveShift = null;
                    let isLeave = 0;
                    
                    if (ad.leave_shift_type === 'FullDay' && halfType !== 'FullDay') {
                        newLeaveShift = halfType === 'FirstHalf' ? 'SecondHalf' : 'FirstHalf';
                        isLeave = 1;
                    } else if (ad.leave_shift_type === halfType) {
                        newLeaveShift = null;
                        isLeave = 0;
                    } else {
                        newLeaveShift = null;
                        isLeave = 0;
                    }

                    // Recalculate shift coverage
                    let curShift = ad.shift_type;
                    if (!ad.first_in_time && !ad.last_out_time && curShift !== 'Absent') {
                        // Safe fallback: If they never punched but shift_type was corrupted to FullDay during approval, revert to Absent.
                        curShift = 'Absent';
                    }

                    const regShift = ad.regularization_shift_type;
                    const odShift = ad.onduty_shift_type;

                    const firstHalf = ['FirstHalf', 'FullDay'].includes(curShift) ||
                                      ['FirstHalf', 'FullDay'].includes(regShift) ||
                                      ['FirstHalf', 'FullDay'].includes(odShift) ||
                                      (isLeave && ['FirstHalf', 'FullDay'].includes(newLeaveShift));

                    const secondHalf = ['SecondHalf', 'FullDay'].includes(curShift) ||
                                       ['SecondHalf', 'FullDay'].includes(regShift) ||
                                       ['SecondHalf', 'FullDay'].includes(odShift) ||
                                       (isLeave && ['SecondHalf', 'FullDay'].includes(newLeaveShift));

                    const finalShift = (firstHalf && secondHalf) ? 'FullDay'
                                     : firstHalf                  ? 'FirstHalf'
                                     : secondHalf                 ? 'SecondHalf'
                                     : 'Absent';

                    const finalDeduct = (!firstHalf && !secondHalf) ? 1.00
                                      : (firstHalf && secondHalf)   ? 0.00
                                      : 0.50;

                    let finalStatus = (finalShift === 'FullDay' || curShift === 'FullDay') ? 'Present' : 
                                        isLeave ? 'Leave' : 'Absent';

                    if (['WeekEnd', 'Public Holiday', 'Exceptional Holiday'].includes(ad.status)) {
                        finalStatus = ad.status;
                    }

                    await conn.execute(
                        `UPDATE attendance_daily
                         SET status = ?, deduction_days = ?, is_leave = ?, leave_shift_type = ?
                         WHERE employee_id = ? AND date = ?`,
                        [finalStatus, finalDeduct, isLeave, newLeaveShift, lr.employee_id, dateStr]
                    );
                }
            }

            // 3. Mark as Cancelled
            await conn.execute(
                `UPDATE leave_requests 
                 SET status = 'Cancelled', 
                     approved_by_id = ?, 
                     approved_on = NOW()
                 WHERE leave_request_id = ?`,
                [cancellerId, requestId]
            );

            await conn.commit();
            return { success: true, message: 'Leave request cancelled successfully' };
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }
}

module.exports = LeaveModel;
