const express = require('express');
const { getHolidays, saveHoliday, deleteHoliday, getSettings, updateSetting } = require('../controllers/holidayController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

// All routes are protected
router.use(protect);

// Holiday Routes
router.get('/', getHolidays);
router.post('/', authorize('Admin'), saveHoliday);
router.delete('/:id', authorize('Admin'), deleteHoliday);

// Attendance Setting Routes
router.get('/settings', getSettings);
router.put('/settings', authorize('Admin'), updateSetting);

module.exports = router;
