const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/auth');
const genericApprovalController = require('../controllers/genericApprovalController');
const operationApproverConfigController = require('../controllers/operationApproverConfigController');

// All routes require login
router.use(protect);

// Approval request endpoints
router.get('/operations', genericApprovalController.getPendingApprovals);
router.get('/operations/my-requests', genericApprovalController.getMyRequests);
router.get('/operations/history', genericApprovalController.getApprovalsHistory);
router.post('/operations/:id/action', genericApprovalController.actionApproval);
router.get('/check-access', genericApprovalController.checkAccess);

// Configurations endpoints (Restricted to Super Admin/Principal)
router.get('/operation-config', authorize('super_admin', 'Principal', 'principal', 'Super Admin'), operationApproverConfigController.getConfigs);
router.get('/operation-config/:type', authorize('super_admin', 'Principal', 'principal', 'Super Admin'), operationApproverConfigController.getConfigByType);
router.post('/operation-config', authorize('super_admin', 'Principal', 'principal', 'Super Admin'), operationApproverConfigController.saveConfig);

module.exports = router;
