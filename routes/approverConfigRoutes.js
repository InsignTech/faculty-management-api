const express = require('express');
const {
    getConfig,
    getConfigByType,
    saveConfig,
    checkSubstitute,
    checkApproverStatus
} = require('../controllers/approverConfigController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

// Check if current user is an approver of anybody or admin
router.get('/check-my-status', checkApproverStatus);

// Get all approver configs for an employee
router.get('/:employeeId', getConfig);

// Get approver config for a specific request type
router.get('/:employeeId/:requestType', getConfigByType);

// Save/update approver config (Admin/Principal/Operations Manager)
router.post('/', authorize('Admin', 'Principal', 'HOD', 'super_admin', 'Operations Manager', 'operations manager'), saveConfig);

// Check substitute availability (any authenticated user)
router.get('/check-substitute', checkSubstitute);

module.exports = router;
