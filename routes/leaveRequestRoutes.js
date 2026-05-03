const express = require('express');
const { getLeaveRequests, createLeaveRequest, getTeamRequests, updateRequestStatus, getEmployeeBalance, checkHolidays, cancelLeaveRequest } = require('../controllers/leaveRequestController');
const { protect } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

router.get('/', getLeaveRequests);
router.post('/', createLeaveRequest);
router.get('/team', getTeamRequests);
router.put('/:id/status', updateRequestStatus);
router.get('/balance/:employeeId', getEmployeeBalance);
router.get('/holidays-check', checkHolidays);
router.delete('/:id', cancelLeaveRequest);



module.exports = router;
