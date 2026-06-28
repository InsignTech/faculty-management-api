const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '..', '..', 'high-end-admin-dashboard', 'src', 'pages', 'PayrollCenter.tsx');
const content = fs.readFileSync(filePath, 'utf8');
const lines = content.split('\n');

for (let i = 600; i <= 800; i++) {
    const line = lines[i];
    if (line && line.includes('\\')) {
        console.log(`Line ${i + 1}: ${line}`);
    }
}
