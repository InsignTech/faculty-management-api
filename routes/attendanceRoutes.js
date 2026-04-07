const express = require('express');
const { 
    processAttendanceLogs, 
    getMyAttendance, 
    getMyAttendanceSummary,
    requestAdjustment, 
    getMyAdjustments,
    getPendingAdjustments,
    approveAdjustment,
    rejectAdjustment,
    uploadMachineLogs
} = require('../controllers/attendanceController');
const { protect, authorize, protectMachine } = require('../middleware/auth');
const router = express.Router();

// Machine Sync Route (uses static API Key)
router.post('/machine-logs', protectMachine, uploadMachineLogs);

// All other routes are protected by standard JWT
router.use(protect);

router.post('/process-logs', authorize('Admin'), processAttendanceLogs); 
router.get('/my-attendance', getMyAttendance);
router.get('/my-summary', getMyAttendanceSummary);
router.post('/adjustments', requestAdjustment);
router.get('/my-adjustments', getMyAdjustments);

// Admin / Manager routes
router.get('/pending-adjustments', authorize('Admin'), getPendingAdjustments);
router.put('/adjustments/:id/approve', authorize('Admin'), approveAdjustment);
router.put('/adjustments/:id/reject', authorize('Admin'), rejectAdjustment);

module.exports = router;
