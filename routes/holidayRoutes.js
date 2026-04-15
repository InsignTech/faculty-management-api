const express = require('express');
const { getHolidays, saveHoliday, deleteHoliday, getSettings, updateSetting } = require('../controllers/holidayController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

// All routes are protected and restricted to Admin/Principal
router.use(protect);

router.get('/', getHolidays);
router.post('/', authorize('Admin', 'Principal', 'super_admin'), saveHoliday);
router.delete('/:id', authorize('Admin', 'Principal', 'super_admin'), deleteHoliday);

// Settings routes - Accessible by Admin/Principal
router.get('/settings', authorize('Admin', 'Principal', 'super_admin'), getSettings);
router.put('/settings', authorize('Admin', 'Principal', 'super_admin'), updateSetting);

module.exports = router;
