const express = require('express');
const { getLeaveRequests, updateRequestStatus, getEmployeeBalance } = require('../controllers/leaveRequestController');
const { protect } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

router.get('/', getLeaveRequests);
router.put('/:id/status', updateRequestStatus);
router.get('/balance/:employeeId', getEmployeeBalance);

module.exports = router;
