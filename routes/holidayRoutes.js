const express = require('express');
const { 
  getGeneralHolidays, 
  getEmployeeHolidays, 
  saveHoliday, 
  deleteHoliday,
  getUpcomingHolidays,
  getPersonalHolidays
} = require('../controllers/holidayController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

// Accessible by all authenticated users
router.get('/upcoming', getUpcomingHolidays);
router.get('/personal', getPersonalHolidays);

// Management routes restricted to Admin/Principal/super_admin
router.use(authorize('Admin', 'Principal', 'super_admin', 'admin', 'Super Admin', 'principal'));

router.get('/general', getGeneralHolidays);
router.get('/employees', getEmployeeHolidays);
router.post('/', saveHoliday);
router.delete('/:id', deleteHoliday);

module.exports = router;
