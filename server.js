require('dotenv').config();
const debugLog = require('./utils/debugLogger');

debugLog("🚀 Starting app...");

// Catch sync crashes
process.on("uncaughtException", (err) => {
  debugLog(`❌ UNCAUGHT EXCEPTION: ${err.message}`, 'ERROR');
  debugLog(err.stack, 'ERROR');
  process.exit(1);
});

// Catch async crashes
process.on("unhandledRejection", (err) => {
  debugLog(`❌ UNHANDLED REJECTION: ${err.message}`, 'ERROR');
  if (err.stack) debugLog(err.stack, 'ERROR');
});

debugLog("Step 1: Loading dependencies...");
const app = require('./app');
const pool = require('./config/db');

// Initialize Cron Jobs
require('./cron/attendanceCron');
require('./cron/leaveCron');

debugLog("Step 2: Deployment timestamp...");
console.log("🔥 NEW DEPLOY -", new Date().toISOString());

const PORT = process.env.PORT || 5000;


const startServer = async () => {
    try {
        debugLog("Step 3: Connecting to database...");
        // Test database connection
        await pool.query('SELECT 1');
        debugLog('Database connection successful');

        const server = app.listen(PORT, () => {
            console.log(`Server running in ${process.env.NODE_ENV} mode on port ${PORT}`);
        });

        // Handle unhandled promise rejections
        process.on('unhandledRejection', (err, promise) => {
            console.log(`Error: ${err.message}`);
            // Close server & exit process
            server.close(() => process.exit(1));
        });
    } catch (error) {
        console.error('Database connection failed:', error.message);
        process.exit(1);
    }
};

startServer();
