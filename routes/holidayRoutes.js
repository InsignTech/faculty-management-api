const express = require('express');
const { 
  getGeneralHolidays, 
  getEmployeeHolidays, 
  saveHoliday, 
  deleteHoliday 
} = require('../controllers/holidayController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

// All routes are protected and restricted to Admin/Principal/super_admin
router.use(protect);
router.use(authorize('Admin', 'Principal', 'super_admin'));

router.get('/general', getGeneralHolidays);
router.get('/employees', getEmployeeHolidays);
router.post('/', saveHoliday);
router.delete('/:id', deleteHoliday);

module.exports = router;
