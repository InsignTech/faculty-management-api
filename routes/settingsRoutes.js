const express = require('express');
const router = express.Router();
const { getSetting } = require('../controllers/settingsController');
const { protect } = require('../middleware/auth');

router.get('/:key', protect, getSetting);

module.exports = router;
