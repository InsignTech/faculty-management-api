const pool = require('./config/db');
const AttendanceModel = require('./models/attendanceModel');

async function checkAndFix() {
    try {
        console.log("Checking attendance for employee 48 on 2026-05-12...");
        const [rows] = await pool.execute(
            "SELECT * FROM attendance_daily WHERE employee_id = 48 AND date = '2026-05-12'"
        );
        console.log("Record:", rows[0]);

        if (rows.length > 0 && rows[0].status === 'Leave') {
            console.log("Status is 'Leave'. Reverting now...");
            await AttendanceModel.revertLeave(48, '2026-05-12', '2026-05-12');
            console.log("Revert call finished.");
            
            const [rows2] = await pool.execute(
                "SELECT * FROM attendance_daily WHERE employee_id = 48 AND date = '2026-05-12'"
            );
            console.log("Updated Record:", rows2[0]);
        } else {
            console.log("Status is not 'Leave' or record not found.");
        }
    } catch (err) {
        console.error(err);
    } finally {
        process.exit(0);
    }
}

checkAndFix();
