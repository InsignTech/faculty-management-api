const express = require('express');
const { 
    getAttendanceReport, 
    exportAttendanceReport,
    getDeductionsReport,
    exportDeductionsReport,
    getLeaveFlowReport,
    getLeaveFlowDetails
} = require('../controllers/reportController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

// Accessible by Managers and Admins/Principal
router.get('/attendance', getAttendanceReport);
router.get('/attendance/export', exportAttendanceReport);

router.get('/deductions', getDeductionsReport);
router.get('/deductions/export', exportDeductionsReport);

// Super admin / Principal audit flow
router.get('/leave-flow', authorize('super_admin', 'principal'), getLeaveFlowReport);
router.get('/leave-flow/details', authorize('super_admin', 'principal'), getLeaveFlowDetails);

module.exports = router;
