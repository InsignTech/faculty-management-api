const express = require('express');
const { 
    getAttendanceReport, 
    exportAttendanceReport,
    getDeductionsReport,
    exportDeductionsReport
} = require('../controllers/reportController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

// Accessible by Managers and Admins/Principal
router.get('/attendance', getAttendanceReport);
router.get('/attendance/export', exportAttendanceReport);

router.get('/deductions', getDeductionsReport);
router.get('/deductions/export', exportDeductionsReport);

module.exports = router;
