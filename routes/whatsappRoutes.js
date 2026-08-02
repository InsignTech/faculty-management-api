const express = require('express');
const router = express.Router();
const whatsappAuth = require('../middleware/whatsappAuth');
const whatsappController = require('../controllers/whatsappController');

router.post('/message', whatsappAuth, whatsappController.handleMessage);

module.exports = router;
