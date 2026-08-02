const express = require('express');
const router = express.Router();
const whatsappAuth = require('../middleware/whatsappAuth');
const whatsappController = require('../controllers/whatsappController');

router.post('/message', whatsappAuth, whatsappController.handleMessage);
router.post('/test-pdf', whatsappController.testPdf);
router.get('/test-pdf', whatsappController.testPdf);

module.exports = router;
