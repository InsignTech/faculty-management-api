const pool = require('../config/db');

async function main() {
    try {
        const startDate = '2026-06-01';
        const endDate = '2026-07-01';
        
        const sql = `
            SELECT 
                ad.date,
                ad.employee_id,
                e.employee_code,
                e.employee_name,
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
            WHERE ad.deduction_days > 0
              AND ad.date BETWEEN ? AND ?

            UNION ALL

            SELECT 
                ad.date,
                ad.employee_id,
                e.employee_code,
                e.employee_name,
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
            WHERE ad.deduction_days > 0
              AND ad.date BETWEEN ? AND ?

            UNION ALL

            SELECT 
                ad.date,
                ad.employee_id,
                e.employee_code,
                e.employee_name,
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
            WHERE ad.deduction_days > 0
              AND ad.date BETWEEN ? AND ?
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
        `;
        
        console.log('Testing SQL Query V2...');
        const [rows] = await pool.query(sql, [startDate, endDate, startDate, endDate, startDate, endDate]);
        console.log(`Success! Found ${rows.length} rows.`);
        if (rows.length > 0) {
            console.log('Sample Row:', rows[0]);
        }
    } catch (e) {
        console.error('SQL Error:', e);
    } finally {
        process.exit();
    }
}
main();
