async function test() {
    try {
        console.log("Sending simulated ADMS attendance log data...");
        const response = await fetch(
            'http://localhost:5000/iclock/cdata.aspx?SN=TESTDEVICE&table=ATTLOG',
            {
                method: 'POST',
                body: '4 2026-07-09 20:00:00\t1\t0\t0\t0\t0\t0',
                headers: { 'Content-Type': 'text/plain' }
            }
        );
        const text = await response.text();
        console.log("Response:", text);

        // Wait a second for DB write
        await new Promise(r => setTimeout(r, 1000));

        const pool = require('../config/db');
        const [rows] = await pool.query(
            "SELECT * FROM attendance_punches_detail WHERE employee_code = '4' AND punch_time = '2026-07-09 20:00:00'"
        );
        console.log("Inserted Row:", rows[0]);
    } catch (err) {
        console.error("Error:", err.message);
    } finally {
        process.exit();
    }
}
test();
