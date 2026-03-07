const express = require('express');
const { getHealth } = require('../controllers/healthController');
const router = express.Router();

/**
 * @swagger
 * /api/health:
 *   get:
 *     summary: Health check endpoint
 *     description: Returns the status and uptime of the API
 *     responses:
 *       200:
 *         description: API is healthy
 */
router.get('/', getHealth);

module.exports = router;
