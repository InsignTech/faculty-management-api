const express = require('express');
const { 
    getLeaveBalance, 
    getLeaveTypes, 
    applyLeave, 
    getMyRequests, 
    getApprovals, 
    actionRequest 
} = require('../controllers/leaveController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

// Employee routes
router.get('/balance', getLeaveBalance);
router.get('/types', getLeaveTypes);
router.get('/my-requests', getMyRequests);
router.post('/apply', applyLeave);

// Manager/Admin routes
router.get('/approvals', authorize('Admin', 'Principal', 'HOD', 'super_admin'), getApprovals);
router.put('/action/:id', authorize('Admin', 'Principal', 'HOD', 'super_admin'), actionRequest);

module.exports = router;
