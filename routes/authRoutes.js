const express = require('express');
const { signup, login, requestOTP, resetWithOTP, resetWithOldPassword } = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const router = express.Router();

/**
 * @swagger
 * /api/auth/signup:
... (kept basic signup doc)
 */
router.post('/signup', signup);

/**
 * @swagger
 * /api/auth/login:
... (kept basic login doc)
 */
router.post('/login', login);

router.post('/request-otp', requestOTP);
router.post('/reset-with-otp', resetWithOTP);
router.post('/reset-with-old', protect, resetWithOldPassword);

module.exports = router;
