const axios = require('axios');

const API_URL = 'http://localhost:5000/api/attendance/machine-logs';
const ADMIN_TOKEN = 'YOUR_ADMIN_TOKEN_HERE'; // Replace with a real token for testing

async function testBulkUpload() {
    console.log('--- Starting Bulk Upload Test ---');
    
    // Generate 300 mock records
    const logs = [];
    const today = new Date().toISOString().split('T')[0];
    
    for (let i = 1; i <= 300; i++) {
        logs.push({
            employee_id: (i % 10) + 1, // IDs 1-10
            punch_time: `${today} 09:0${Math.floor(i/60)}:${String(i%60).padStart(2, '0')}`
        });
    }

    // Add some deliberate duplicates to test UNIQUE constraint
    logs.push(logs[0]); 
    logs.push(logs[1]);

    try {
        const response = await axios.post(API_URL, logs, {
            headers: {
                'Authorization': `Bearer ${ADMIN_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });

        console.log('Status:', response.status);
        console.log('Response:', response.data);
    } catch (error) {
        console.error('Error:', error.response ? error.response.data : error.message);
    }
}

// testBulkUpload(); // Uncomment and run with node
console.log('To run this test:');
console.log('1. Ensure backend is running at http://localhost:5000');
console.log('2. Replace YOUR_ADMIN_TOKEN_HERE with a valid JWT');
console.log('3. Run: node scripts/test-machine-upload.js');
