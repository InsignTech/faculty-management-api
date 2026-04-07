const express = require('express');
const { requestLeaveEncashment, getMyLeaveEncashments, getPendingEncashments } = require('../controllers/leaveEncashmentController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

router.post('/', requestLeaveEncashment);
router.get('/', getMyLeaveEncashments);
router.get('/pending', authorize('Admin'), getPendingEncashments);

module.exports = router;
