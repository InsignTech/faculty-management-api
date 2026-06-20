const express = require('express');
const router = express.Router();

// Middlewares: parse raw text since ADMS devices send data in custom text formats
router.use(express.text({ type: '*/*', limit: '10mb' }));

const handleAdmsRequest = async (req, res) => {
    console.log('====== ADMS / eSSL Device Request Received ======');
    console.log('Time:', new Date().toISOString());
    console.log('HTTP Method:', req.method);
    console.log('Original URL:', req.originalUrl);
    console.log('Query Parameters:', req.query);
    console.log('Headers:', req.headers);
    console.log('Body Length:', req.body ? req.body.length : 0);
    
    if (req.body) {
        console.log('Body Preview (first 1000 chars):');
        console.log(req.body.substring(0, 1000));
    }
    
    const { SN, table } = req.query;

    if (req.method === 'POST' && table === 'ATTLOG' && req.body) {
        const pool = require('../config/db');
        const lines = req.body.split('\n');
        
        for (let line of lines) {
            line = line.trim();
            if (!line) continue;

            // Example line: 2001 2026-06-20 13:18:40     255     15      0       0       0       0       0       0
            // Parts: [ '2001', '2026-06-20', '13:18:40', '255', '15', '0', '0', '0', '0', '0', '0' ]
            const parts = line.split(/\s+/);
            if (parts.length >= 3) {
                const employeeCode = parts[0];
                const punchTime = `${parts[1]} ${parts[2]}`; // YYYY-MM-DD HH:mm:ss
                const punchState = parts[3] || null;
                const verifyMode = parts[4] || null;
                const workCode = parts[5] || null;
                
                try {
                    await pool.query(
                        `INSERT INTO attendance_punches 
                        (device_sn, employee_code, punch_time, punch_state, verify_mode, work_code, raw_data) 
                        VALUES (?, ?, ?, ?, ?, ?, ?)`,
                        [SN || 'UNKNOWN', employeeCode, punchTime, punchState, verifyMode, workCode, line]
                    );
                } catch (err) {
                    console.error('Error inserting punch:', err);
                }
            }
        }
    }

    console.log('================================================');

    // Respond back to the device to acknowledge receipt
    res.status(200).send('OK');
};

// Define explicit routes used by eSSL / ZKTeco ADMS devices (with and without .aspx extension)
// router.all('/cdata', handleAdmsRequest);
router.all('/cdata.aspx', handleAdmsRequest);

// router.all('/getrequest', handleAdmsRequest);
// router.all('/getrequest.aspx', handleAdmsRequest);

// router.all('/registry', handleAdmsRequest);
// router.all('/registry.aspx', handleAdmsRequest);

// router.all('/devicecmd', handleAdmsRequest);
// router.all('/devicecmd.aspx', handleAdmsRequest);

// router.all('/', handleAdmsRequest);

module.exports = router;
