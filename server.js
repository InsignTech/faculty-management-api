const app = require('./app');
const pool = require('./config/db');
require('dotenv').config();

console.log("🔥 NEW DEPLOY -", new Date().toISOString());

const PORT = process.env.PORT || 5000;

const startServer = async () => {
    try {
        // Test database connection
        await pool.query('SELECT 1');
        console.log('Database connection successful');

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
