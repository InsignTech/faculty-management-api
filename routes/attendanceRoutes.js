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
    approveBatchAdjustment,
    rejectAdjustment,
    rejectBatchAdjustment,
    deleteAdjustment,
    deleteBatchAdjustment,
    uploadMachineLogs,
    superAdminUpdateAttendance,
    superAdminApplyAdjustment,
    uploadMachineLogsMesEdathala,
    previewAdjustmentRange
} = require('../controllers/attendanceController');
const { protect, authorize, protectMachine } = require('../middleware/auth');
const router = express.Router();

// Machine Sync Route (uses static API Key)
router.post('/machine-logs', protectMachine, uploadMachineLogs);

router.post('/machine-logs-mesedathala', uploadMachineLogsMesEdathala);
// All other routes are protected by standard JWT
router.use(protect);

// Super admin override routes
router.put('/super-admin/update-attendance', authorize('super_admin', 'principal', 'Super Admin', 'Principal'), superAdminUpdateAttendance);
router.post('/super-admin/apply-adjustment', authorize('super_admin', 'principal', 'Super Admin', 'Principal'), superAdminApplyAdjustment);

router.post('/process-logs', authorize('Admin'), processAttendanceLogs);

router.get('/my-attendance', getMyAttendance);
router.get('/my-summary', getMyAttendanceSummary);
router.get('/irregular-days', getIrregularDays);
router.get('/adjustments/preview-range', previewAdjustmentRange);
router.post('/adjustments', requestAdjustment);
router.get('/my-adjustments', getMyAdjustments);
router.delete('/adjustments/batch/:batchId', deleteBatchAdjustment);
router.delete('/adjustments/:id', deleteAdjustment);

// Admin / Manager routes
router.get('/pending-adjustments', getPendingAdjustments);
router.put('/adjustments/batch/:batchId/approve', approveBatchAdjustment);
router.put('/adjustments/:id/approve', approveAdjustment);
router.put('/adjustments/batch/:batchId/reject', rejectBatchAdjustment);
router.put('/adjustments/:id/reject', rejectAdjustment);

module.exports = router;
