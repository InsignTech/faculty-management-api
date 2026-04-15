const pool = require('../config/db');

class ReportModel {
    /**
     * Get attendance report for a given date range and filters
     */
    static async getAttendanceReport(managerId, isAdmin, filters) {
        const { startDate, endDate, employeeId, departmentId } = filters;

        // 1. Get employee list based on hierarchy/role
        let employeePoolQuery = `
            SELECT 
                e.employee_id, e.employee_code, e.employee_name, 
                d.department_name, r.role_name, 
                e.reporting_manager_id,
                e.role_id, e.designation_id
            FROM employee e
            LEFT JOIN department d ON e.department_id = d.department_id
            LEFT JOIN role r ON e.role_id = r.role_id
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

        const [employees] = await pool.execute(employeePoolQuery, params);

        // 2. Fetch all raw data for the range
        // Attendance
        const [attendance] = await pool.execute(
            `SELECT * FROM attendance WHERE date BETWEEN ? AND ?`,
            [startDate, endDate]
        );

        // Leaves
        const [leaves] = await pool.execute(
            `SELECT * FROM leave_requests WHERE status = 'Approved' 
             AND (start_date <= ? AND end_date >= ?)`,
            [endDate, startDate]
        );

        // Holidays
        const [holidays] = await pool.execute(
            `SELECT * FROM holidays WHERE is_active = 1 AND holiday_date BETWEEN ? AND ?`,
            [startDate, endDate]
        );

        // Policies (for Weekly Offs)
        const [systemPolicy] = await pool.execute(`SELECT weekly_off FROM leave_policy_system WHERE active = 1`);
        const [rolePolicies] = await pool.execute(`SELECT role_id, weekly_off FROM leave_policy_role WHERE active = 1`);
        const [designationPolicies] = await pool.execute(`SELECT designation_id, weekly_off FROM leave_policy_designation WHERE active = 1`);
        const [employeePolicies] = await pool.execute(`SELECT employee_id, weekly_off FROM leave_policy_employee WHERE active = 1`);

        // 3. Process the matrix
        const report = [];
        const start = new Date(startDate);
        const end = new Date(endDate);

        for (const emp of employees) {
            let curr = new Date(start);
            
            // Resolve Weekly Off for this employee
            const empWO = employeePolicies.find(p => p.employee_id === emp.employee_id);
            const desigWO = designationPolicies.find(p => p.designation_id === emp.designation_id);
            const roleWO = rolePolicies.find(p => p.role_id === emp.role_id);
            const sysWO = systemPolicy[0] || { weekly_off: '["Sunday"]' };

            const weeklyOffs = JSON.parse(
                (empWO && empWO.weekly_off) || 
                (desigWO && desigWO.weekly_off) || 
                (roleWO && roleWO.weekly_off) || 
                sysWO.weekly_off || '["Sunday"]'
            );

            while (curr <= end) {
                const dateStr = curr.toISOString().split('T')[0];
                const dayName = curr.toLocaleDateString('en-US', { weekday: 'long' });

                // Find data for this day
                const empAttendance = attendance.find(a => a.employee_id === emp.employee_id && a.date.toISOString().split('T')[0] === dateStr);
                const empLeave = leaves.find(l => {
                    const lStart = new Date(l.start_date);
                    const lEnd = new Date(l.end_date);
                    return l.employee_id === emp.employee_id && curr >= lStart && curr <= lEnd;
                });
                const isHoliday = holidays.find(h => h.holiday_date.toISOString().split('T')[0] === dateStr);
                const isWeeklyOff = weeklyOffs.includes(dayName);

                let status = 'Absent';
                let remark = '';

                if (empAttendance) {
                    status = empAttendance.is_late ? 'Late' : 'Present';
                    remark = empAttendance.type === 'Onduty' ? 'On Duty' : '';
                } else if (empLeave) {
                    status = 'Leave';
                    remark = empLeave.leave_type;
                } else if (isHoliday) {
                    status = 'Holiday';
                    remark = isHoliday.description;
                } else if (isWeeklyOff) {
                    status = 'Weekly Off';
                }

                report.push({
                    employee_id: emp.employee_id,
                    employee_code: emp.employee_code,
                    employee_name: emp.employee_name,
                    department: emp.department_name,
                    date: dateStr,
                    status: status,
                    remark: remark,
                    punch_in: empAttendance && empAttendance.type === 'PunchIn' ? empAttendance.punch_time : null,
                    punch_out: empAttendance && empAttendance.type === 'PunchOut' ? empAttendance.punch_time : null,
                });

                curr.setDate(curr.getDate() + 1);
            }
        }

        return report;
    }
}

module.exports = ReportModel;
