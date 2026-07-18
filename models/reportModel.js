const pool = require('../config/db');

class ReportModel {
    /**
     * Get attendance report for a given date range and filters
     */
    static async getAttendanceReport(managerId, isAdmin, { startDate, endDate, employeeId, departmentId, search }) {
        // 1. Get employee list based on hierarchy/role
        let employeePoolQuery = `
            SELECT 
                e.employee_id, e.employee_code, e.employee_name, 
                d.departmentname as department, r.role, 
                e.reporting_manager_id,
                e.role_id, e.designation_id
            FROM employee e
            LEFT JOIN department d ON e.department_id = d.department_id
            LEFT JOIN app_role r ON e.role_id = r.role_id
            WHERE e.active = 1
        `;

        const params = [];

        if (!isAdmin) {
            // Filter by subordinates
            employeePoolQuery += `
                AND (e.employee_id IN (
                    WITH RECURSIVE Subordinates AS (
                        SELECT employee_id FROM employee WHERE reporting_manager_id = ?
                        UNION ALL
                        SELECT e2.employee_id FROM employee e2
                        INNER JOIN Subordinates s ON e2.reporting_manager_id = s.employee_id
                    )
                    SELECT employee_id FROM Subordinates
                ) OR e.employee_id = ?)
            `;
            params.push(managerId, managerId);
        }

        if (employeeId) {
            employeePoolQuery += ` AND e.employee_id = ?`;
            params.push(employeeId);
        }

        if (departmentId) {
            employeePoolQuery += ` AND e.department_id = ?`;
            params.push(departmentId);
        }

        if (search) {
            employeePoolQuery += ` AND (e.employee_name LIKE ? OR e.employee_code LIKE ?)`;
            params.push(`%${search}%`, `%${search}%`);
        }

        const [employees] = await pool.execute(employeePoolQuery, params);

        // 2. Fetch all raw data for the range
        // Attendance
        const [attendance] = await pool.execute(
            `SELECT *, DATE_FORMAT(date, '%Y-%m-%d') as formatted_date FROM attendance_daily WHERE date BETWEEN ? AND ?`,
            [startDate, endDate]
        );

        // Leaves
        const [leaves] = await pool.execute(
            `SELECT * FROM leave_requests WHERE status = 'Approved' 
             AND (start_date <= ? AND end_date >= ?)`,
            [endDate, startDate]
        );

        // Holidays & Weekly Offs (using holiday_master)
        const [holidays] = await pool.execute(
            `SELECT holiday_name as description, holiday_start_date, holiday_end_date, holiday_type, employee_id 
             FROM holiday_master 
             WHERE is_active = 1 
             AND (holiday_start_date <= ? AND holiday_end_date >= ?)`,
            [endDate, startDate]
        );

        // 3. Process the matrix
        const report = [];
        const start = new Date(startDate);
        const end = new Date(endDate);

        let curr = new Date(start);
        while (curr <= end) {
            const dateStr = curr.toISOString().split('T')[0];

            for (const emp of employees) {
                const dayAttendance = attendance.find(a => {
                    const aDate = new Date(a.date).toISOString().split('T')[0];
                    return a.employee_id === emp.employee_id && aDate === dateStr;
                });

                const dayLeaves = leaves.filter(l => {
                    const lStart = new Date(l.start_date);
                    const lEnd = new Date(l.end_date);
                    return l.employee_id === emp.employee_id && curr >= lStart && curr <= lEnd;
                });
                const empLeave = dayLeaves.length > 0 ? dayLeaves[0] : null;
                
                const empHoliday = holidays.find(h => {
                    const hStart = new Date(h.holiday_start_date);
                    const hEnd = new Date(h.holiday_end_date);
                    // Reset times for date-only comparison
                    const d = new Date(curr);
                    d.setHours(0,0,0,0);
                    hStart.setHours(0,0,0,0);
                    hEnd.setHours(0,0,0,0);
                    return d >= hStart && d <= hEnd && (h.employee_id === -1 || h.employee_id === emp.employee_id);
                });

                let status = 'Absent';
                let remark = '';

                if (dayAttendance) {
                    const hasPunchIn = dayAttendance.first_in_time;
                    const hasPunchOut = dayAttendance.last_out_time;

                    // Mixed Status Logic
                    const isReg = dayAttendance.regularization_shift_type !== null;
                    const isOD = dayAttendance.onduty_shift_type !== null;
                    const isLeave = Number(dayAttendance.is_leave) === 1 || dayAttendance.status === 'Leave' || dayAttendance.leave_shift_type !== null;

                    if (isOD && isLeave) {
                        status = 'On-Duty + Leave';
                        const leaveInfo = dayLeaves.length > 0 
                            ? dayLeaves.map(l => `${l.leave_type} (${l.leave_half_type || 'FullDay'})`).join(', ')
                            : (empLeave ? empLeave.leave_type : 'Leave');
                        remark = `${leaveInfo} (OD)`;
                    } else if (isReg && isLeave) {
                        status = 'Regularized + Leave';
                        const leaveInfo = dayLeaves.length > 0 
                            ? dayLeaves.map(l => `${l.leave_type} (${l.leave_half_type || 'FullDay'})`).join(', ')
                            : (empLeave ? empLeave.leave_type : 'Leave');
                        remark = `${leaveInfo} (Reg)`;
                    }
                    // If it's a processed non-working day or absent, respect that status
                    else if (['WeekEnd', 'Public Holiday', 'Exceptional Holiday', 'Vacation', 'Leave', 'Absent'].includes(dayAttendance.status)) {
                        status = dayAttendance.status === 'WeekEnd' ? 'Weekly Off' : dayAttendance.status;
                        if (dayAttendance.status === 'Leave') {
                            remark = dayLeaves.length > 0 
                                ? dayLeaves.map(l => `${l.leave_type} (${l.leave_half_type || 'FullDay'})`).join(', ')
                                : (empLeave ? empLeave.leave_type : 'Leave');
                        } else if (dayAttendance.status === 'Absent') {
                            remark = '';
                        } else {
                            remark = dayAttendance.status;
                        }
                    } 
                    // Priority: On Duty
                    else if (isOD) {
                        status = 'On-Duty';
                        remark = 'On Duty';
                    }
                    // Priority: Regularized
                    else if (isReg) {
                        status = 'Regularized';
                        remark = 'Regularized';
                    } 
                    // Incomplete punch
                    else if (!hasPunchIn || !hasPunchOut) {
                        status = 'Absent';
                    } 
                    // Irregular (Late/Early)
                    else if (dayAttendance.is_late === 1 || dayAttendance.is_early_leaving === 1) {
                        status = 'Regularization Required';
                    } 
                    // Normal Present
                    else {
                        status = 'Present';
                    }
                } else if (empLeave) {
                    status = 'Leave';
                    remark = empLeave.leave_type;
                } else if (empHoliday) {
                    if (empHoliday.holiday_type === 'WeekEnd') {
                        status = 'Weekly Off';
                    } else {
                        status = 'Holiday';
                        remark = empHoliday.description;
                    }
                }

                report.push({
                    employee_id: emp.employee_id,
                    employee_code: emp.employee_code,
                    employee_name: emp.employee_name,
                    department: emp.department, 
                    date: dateStr,
                    status: status,
                    remark: remark,
                    punch_in: dayAttendance ? dayAttendance.first_in_time : null,
                    punch_out: dayAttendance ? dayAttendance.last_out_time : null,
                    worked_mins: dayAttendance ? dayAttendance.worked_mins : 0,
                    late_minutes: dayAttendance ? dayAttendance.late_minutes : 0,
                    early_minutes: dayAttendance ? dayAttendance.early_minutes : 0,
                    overtime_minutes: dayAttendance ? dayAttendance.overtime_minutes : 0,
                    deduction_days: dayAttendance ? parseFloat(dayAttendance.deduction_days) : (status === 'Absent' ? 1.00 : 0.00),
                    shift_type: dayAttendance ? dayAttendance.shift_type : null,
                    regularization_shift_type: dayAttendance ? dayAttendance.regularization_shift_type : null,
                    onduty_shift_type: dayAttendance ? dayAttendance.onduty_shift_type : null,
                    is_leave: dayAttendance ? (dayAttendance.is_leave || (dayAttendance.leave_shift_type ? 1 : 0)) : (empLeave ? 1 : 0),
                    is_leave_type: empLeave ? empLeave.leave_type : (dayAttendance && dayAttendance.status === 'Leave' ? 'Leave' : null),
                    leave_shift_type: dayAttendance ? dayAttendance.leave_shift_type : (empLeave ? empLeave.leave_half_type : null)
                });
            }
            curr.setDate(curr.getDate() + 1);
        }

        return report;
    }

    static async getDeductionsReport(managerId, isAdmin, { startDate, endDate, departmentId, search, filterType }) {
        let sql = `
            SELECT * FROM (
                SELECT 
                    ad.date,
                    ad.employee_id,
                    e.employee_code,
                    e.employee_name,
                    e.department_id,
                    e.reporting_manager_id,
                    dept.departmentname AS department,
                    ad.status AS attendance_status,
                    ad.deduction_days,
                    'Leave' AS request_type,
                    lr.leave_request_id AS request_id,
                    lr.leave_type AS request_details,
                    lr.status AS request_status,
                    lr.current_level,
                    lr.applied_on,
                    lr.approver_1_id,
                    a1.employee_name AS approver_1_name,
                    lr.approver_2_id,
                    a2.employee_name AS approver_2_name,
                    lr.approved_by_id,
                    ab.employee_name AS approved_by_name,
                    lr.approver_1_action_on,
                    lr.approver_2_action_on,
                    lr.approver_1_remarks,
                    lr.approver_2_remarks,
                    lr.reason
                FROM attendance_daily ad
                JOIN employee e ON ad.employee_id = e.employee_id
                LEFT JOIN department dept ON e.department_id = dept.department_id
                JOIN leave_requests lr ON lr.employee_id = ad.employee_id 
                    AND ad.date BETWEEN lr.start_date AND lr.end_date
                    AND lr.status IN ('Pending', 'Approved', 'Rejected')
                LEFT JOIN employee a1 ON lr.approver_1_id = a1.employee_id
                LEFT JOIN employee a2 ON lr.approver_2_id = a2.employee_id
                LEFT JOIN employee ab ON lr.approved_by_id = ab.employee_id
                WHERE ad.deduction_days > 0 AND e.active = 1

                UNION ALL

                SELECT 
                    ad.date,
                    ad.employee_id,
                    e.employee_code,
                    e.employee_name,
                    e.department_id,
                    e.reporting_manager_id,
                    dept.departmentname AS department,
                    ad.status AS attendance_status,
                    ad.deduction_days,
                    ar.request_type AS request_type,
                    ar.id AS request_id,
                    ar.regularization_shift_type AS request_details,
                    ar.status AS request_status,
                    ar.current_level,
                    ar.created_on AS applied_on,
                    ar.approver_1_id,
                    a1.employee_name AS approver_1_name,
                    ar.approver_2_id,
                    a2.employee_name AS approver_2_name,
                    ar.approved_by AS approved_by_id,
                    ab.employee_name AS approved_by_name,
                    ar.approver_1_action_on,
                    ar.approver_2_action_on,
                    ar.approver_1_remarks,
                    ar.approver_2_remarks,
                    ar.reason
                FROM attendance_daily ad
                JOIN employee e ON ad.employee_id = e.employee_id
                LEFT JOIN department dept ON e.department_id = dept.department_id
                JOIN attendance_regularization ar ON ar.employee_id = ad.employee_id 
                    AND ar.date = ad.date
                    AND ar.status IN ('Pending', 'Approved', 'Rejected')
                LEFT JOIN employee a1 ON ar.approver_1_id = a1.employee_id
                LEFT JOIN employee a2 ON ar.approver_2_id = a2.employee_id
                LEFT JOIN employee ab ON ar.approved_by = ab.employee_id
                WHERE ad.deduction_days > 0 AND e.active = 1

                UNION ALL

                SELECT 
                    ad.date,
                    ad.employee_id,
                    e.employee_code,
                    e.employee_name,
                    e.department_id,
                    e.reporting_manager_id,
                    dept.departmentname AS department,
                    ad.status AS attendance_status,
                    ad.deduction_days,
                    'None' AS request_type,
                    NULL AS request_id,
                    NULL AS request_details,
                    'Not Applied' AS request_status,
                    NULL AS current_level,
                    NULL AS applied_on,
                    NULL AS approver_1_id,
                    NULL AS approver_1_name,
                    NULL AS approver_2_id,
                    NULL AS approver_2_name,
                    NULL AS approved_by_id,
                    NULL AS approved_by_name,
                    NULL AS approver_1_action_on,
                    NULL AS approver_2_action_on,
                    NULL AS approver_1_remarks,
                    NULL AS approver_2_remarks,
                    NULL AS reason
                FROM attendance_daily ad
                JOIN employee e ON ad.employee_id = e.employee_id
                LEFT JOIN department dept ON e.department_id = dept.department_id
                WHERE ad.deduction_days > 0 AND e.active = 1
                  AND NOT EXISTS (
                      SELECT 1 FROM leave_requests lr
                      WHERE lr.employee_id = ad.employee_id 
                        AND ad.date BETWEEN lr.start_date AND lr.end_date
                        AND lr.status IN ('Pending', 'Approved', 'Rejected')
                  )
                  AND NOT EXISTS (
                      SELECT 1 FROM attendance_regularization ar
                      WHERE ar.employee_id = ad.employee_id 
                        AND ar.date = ad.date
                        AND ar.status IN ('Pending', 'Approved', 'Rejected')
                  )
            ) AS combined
            WHERE combined.date BETWEEN ? AND ?
        `;

        const params = [startDate, endDate];

        if (!isAdmin) {
            // Filter by subordinates
            sql += `
                AND (combined.employee_id IN (
                    WITH RECURSIVE Subordinates AS (
                        SELECT employee_id FROM employee WHERE reporting_manager_id = ?
                        UNION ALL
                        SELECT e2.employee_id FROM employee e2
                        INNER JOIN Subordinates s ON e2.reporting_manager_id = s.employee_id
                    )
                    SELECT employee_id FROM Subordinates
                ) OR combined.employee_id = ?)
            `;
            params.push(managerId, managerId);
        }

        if (departmentId) {
            sql += ` AND combined.department_id = ?`;
            params.push(departmentId);
        }

        if (search) {
            sql += ` AND (combined.employee_name LIKE ? OR combined.employee_code LIKE ?)`;
            params.push(`%${search}%`, `%${search}%`);
        }

        sql += ` ORDER BY combined.date DESC, combined.employee_name ASC`;

        const [rows] = await pool.execute(sql, params);

        // Process rows to map applied request status and filter based on filterType
        const report = rows.map(row => {
            let requestStatusText = row.request_status;
            if (row.request_status === 'Pending') {
                requestStatusText = `Level ${row.current_level} Pending`;
            }

            return {
                date: row.date,
                employee_id: row.employee_id,
                employee_code: row.employee_code,
                employee_name: row.employee_name,
                department: row.department || 'N/A',
                attendance_status: row.attendance_status,
                deduction_days: parseFloat(row.deduction_days),
                request_type: row.request_type,
                request_details: row.request_details,
                request_status: requestStatusText,
                raw_status: row.request_status,
                current_level: row.current_level,
                applied_on: row.applied_on,
                approver_1_name: row.approver_1_name || 'N/A',
                approver_2_name: row.approver_2_name || 'N/A',
                approved_by_name: row.approved_by_name || 'N/A',
                approver_1_action_on: row.approver_1_action_on,
                approver_2_action_on: row.approver_2_action_on,
                approver_1_remarks: row.approver_1_remarks || '',
                approver_2_remarks: row.approver_2_remarks || '',
                reason: row.reason || ''
            };
        });

        // Apply filterType filter in memory
        if (filterType && filterType !== 'all') {
            return report.filter(row => {
                if (filterType === 'no_request') {
                    return row.raw_status === 'Not Applied';
                }
                if (filterType === 'pending_level_1') {
                    return row.raw_status === 'Pending' && row.current_level === 1;
                }
                if (filterType === 'pending_level_2') {
                    return row.raw_status === 'Pending' && row.current_level === 2;
                }
                if (filterType === 'pending') {
                    return row.raw_status === 'Pending';
                }
                if (filterType === 'approved') {
                    return row.raw_status === 'Approved';
                }
                if (filterType === 'rejected') {
                    return row.raw_status === 'Rejected';
                }
                if (filterType === 'leave') {
                    return row.request_type === 'Leave';
                }
                if (filterType === 'regularization') {
                    return row.request_type === 'Regularization';
                }
                if (filterType === 'onduty') {
                    return row.request_type === 'OnDuty';
                }
                return true;
            });
        }

        return report;
    }
}

module.exports = ReportModel;
