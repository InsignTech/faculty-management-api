const express = require('express');
const router = express.Router();
const {
  getGlobalShifts,
  getAllEmployeeShifts,
  updateGlobalShift,
  assignEmployeeShift,
  deleteEmployeeShiftGroup
} = require('../controllers/shiftController');
const { protect, authorize } = require('../middleware/auth');

// All shift routes require authentication and specific roles
router.use(protect);
router.use(authorize('Admin', 'Principal', 'Super Admin', 'superadmin', 'super_admin', 'principal'));

router.get('/global', getGlobalShifts);
router.get('/employees', getAllEmployeeShifts);
router.put('/global/:id', updateGlobalShift);
router.post('/assign', assignEmployeeShift);
router.post('/delete-group', deleteEmployeeShiftGroup);

module.exports = router;
