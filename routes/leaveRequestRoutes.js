const express = require('express');
const { getLeaveRequests, createLeaveRequest, getTeamRequests, updateRequestStatus, getEmployeeBalance, checkHolidays, cancelLeaveRequest, superAdminApplyLeave, getApprovedSubstitutesList } = require('../controllers/leaveRequestController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

router.get('/', getLeaveRequests);
router.post('/', createLeaveRequest);
router.get('/team', getTeamRequests);
router.get('/substitute-leaves', getApprovedSubstitutesList);
router.put('/:id/status', updateRequestStatus);
router.get('/balance/:employeeId', getEmployeeBalance);
router.get('/holidays-check', checkHolidays);
router.delete('/:id', cancelLeaveRequest);

// Super admin override route
router.post('/super-admin/apply-leave', authorize('super_admin', 'principal', 'Super Admin', 'Principal'), superAdminApplyLeave);

module.exports = router;

