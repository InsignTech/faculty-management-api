const express = require('express');
const { checkMenuBooking, logBody } = require('../controllers/testController');
const router = express.Router();

/**
 * @swagger
 * /api/test/menu-booking:
 *   post:
 *     summary: General testing endpoint for menu pre-bookings
 *     description: Checks or lists employee menu pre-bookings
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               empId:
 *                 type: string
 *                 example: EMP001
 *               time:
 *                 type: string
 *                 example: "12:30"
 *               isAllMenuNeeded:
 *                 type: boolean
 *                 example: false
 *     responses:
 *       200:
 *         description: Success
 */
router.post('/menu-booking', checkMenuBooking);

/**
 * @swagger
 * /api/test/log-body:
 *   post:
 *     summary: General testing endpoint to log request body to console
 *     description: Logs any incoming request body to the server console
 *     responses:
 *       200:
 *         description: Success
 */
router.post('/log-body', logBody);

module.exports = router;
