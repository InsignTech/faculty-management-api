const { sendResponse } = require('../utils/responseHelper');
const pool = require('../config/db');

const getHealth = async (req, res) => {
    const healthData = {
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        dbStatus: 'disconnected'
    };

    try {
        const [rows] = await pool.query('SELECT 1');

        if (rows) {
            healthData.dbStatus = 'connected';
        }

        return sendResponse(res, 200, 'API is healthy', healthData);

    } catch (error) {
        healthData.error = error.message;
        next(new ErrorResponse('API is unhealthy', 500, 'HEALTH_CHECK_FAILED'));
    }
};

module.exports = { getHealth };
