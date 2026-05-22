const express = require('express');
const { 
    processAttendanceLogs, 
    getMyAttendance, 
    getMyAttendanceSummary,
    getIrregularDays,
    requestAdjustment, 
    getMyAdjustments,
    getPendingAdjustments,
    approveAdjustment,
    rejectAdjustment,
    deleteAdjustment,
    uploadMachineLogs,
    superAdminUpdateAttendance,
    superAdminApplyAdjustment
} = require('../controllers/attendanceController');
const { protect, authorize, protectMachine } = require('../middleware/auth');
const router = express.Router();

// Machine Sync Route (uses static API Key)
router.post('/machine-logs', protectMachine, uploadMachineLogs);

// All other routes are protected by standard JWT
router.use(protect);

// Super admin override routes
router.put('/super-admin/update-attendance', authorize('super_admin', 'principal', 'Super Admin', 'Principal'), superAdminUpdateAttendance);
router.post('/super-admin/apply-adjustment', authorize('super_admin', 'principal', 'Super Admin', 'Principal'), superAdminApplyAdjustment);

router.post('/process-logs', authorize('Admin'), processAttendanceLogs); 

router.get('/my-attendance', getMyAttendance);
router.get('/my-summary', getMyAttendanceSummary);
router.get('/irregular-days', getIrregularDays);
router.post('/adjustments', requestAdjustment);
router.get('/my-adjustments', getMyAdjustments);
router.delete('/adjustments/:id', deleteAdjustment);

// Admin / Manager routes
router.get('/pending-adjustments', getPendingAdjustments);
router.put('/adjustments/:id/approve', approveAdjustment);
router.put('/adjustments/:id/reject', rejectAdjustment);

module.exports = router;
