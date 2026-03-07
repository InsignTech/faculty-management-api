const { sendResponse } = require('../utils/responseHelper');

const getHealth = (req, res) => {
    sendResponse(res, 200, 'API is healthy', {
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
    });
};

module.exports = { getHealth };
