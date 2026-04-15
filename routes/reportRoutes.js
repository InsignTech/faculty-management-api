const express = require('express');
const { getAttendanceReport, exportAttendanceReport } = require('../controllers/reportController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

// Accessible by Managers and Admins/Principal
router.get('/attendance', getAttendanceReport);
router.get('/attendance/export', exportAttendanceReport);

module.exports = router;
