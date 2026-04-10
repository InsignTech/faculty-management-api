const fs = require('fs');
const path = require('path');

const logFile = path.join(__dirname, '../debug.log');

const debugLog = (message, type = 'INFO') => {
    const timestamp = new Date().toISOString();
    const formattedMessage = `[${timestamp}] [${type}] ${message}\n`;
    
    // Log to console
    if (type === 'ERROR') {
        console.error(formattedMessage.trim());
    } else {
        console.log(formattedMessage.trim());
    }

    // Log to file
    try {
        fs.appendFileSync(logFile, formattedMessage);
    } catch (err) {
        console.error('Failed to write to debug.log:', err.message);
    }
};

module.exports = debugLog;
