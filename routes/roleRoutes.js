const express = require('express');
const router = express.Router();
const { getRoles, createRole } = require('../controllers/roleController');
const { protect } = require('../middleware/auth');

router.get('/', protect, getRoles);
router.post('/', protect, createRole);

module.exports = router;
