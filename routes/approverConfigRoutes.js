const express = require('express');
const {
    getConfig,
    getConfigByType,
    saveConfig,
    checkSubstitute
} = require('../controllers/approverConfigController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

// Get all approver configs for an employee
router.get('/:employeeId', getConfig);

// Get approver config for a specific request type
router.get('/:employeeId/:requestType', getConfigByType);

// Save/update approver config (Admin/Principal only)
router.post('/', authorize('Admin', 'Principal', 'HOD', 'super_admin'), saveConfig);

// Check substitute availability (any authenticated user)
router.get('/check-substitute', checkSubstitute);

module.exports = router;
