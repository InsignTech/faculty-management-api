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
                    // If it's a processed non-working day, respect that status
                    else if (['WeekEnd', 'Public Holiday', 'Exceptional Holiday', 'Vacation', 'Leave'].includes(dayAttendance.status)) {
                        status = dayAttendance.status === 'WeekEnd' ? 'Weekly Off' : dayAttendance.status;
                        if (dayAttendance.status === 'Leave') {
                            remark = dayLeaves.length > 0 
                                ? dayLeaves.map(l => `${l.leave_type} (${l.leave_half_type || 'FullDay'})`).join(', ')
                                : (empLeave ? empLeave.leave_type : 'Leave');
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
                    // Irregular (Late/Early)
                    else if (dayAttendance.is_late === 1 || dayAttendance.is_early_leaving === 1) {
                        status = 'Regularization Required';
                    } 
                    // Incomplete punch
                    else if (!hasPunchIn || !hasPunchOut) {
                        status = 'Absent';
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
}

module.exports = ReportModel;
