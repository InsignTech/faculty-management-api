const express = require('express');
const { getLeaveBalance, applyLeave, getEmployeeLeaves } = require('../controllers/leaveRequestController');
const { protect } = require('../middleware/auth');
const router = express.Router();

// All routes are protected
router.use(protect);

router.get('/balance', getLeaveBalance);
router.post('/apply', applyLeave);
router.get('/my-leaves', getEmployeeLeaves);

module.exports = router;
