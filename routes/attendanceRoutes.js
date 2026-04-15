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
    deleteAdjustment,
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
router.delete('/adjustments/:id', deleteAdjustment);

// Admin / Manager routes
router.get('/pending-adjustments', getPendingAdjustments);
router.put('/adjustments/:id/approve', approveAdjustment);
router.put('/adjustments/:id/reject', rejectAdjustment);

module.exports = router;
