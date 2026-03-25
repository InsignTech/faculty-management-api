const express = require('express');
const {
  createEmployee,
  getEmployees,
  getPotentialManagers,
  getEmployeeById,
  updateEmployee,
  deleteEmployee,
} = require('../controllers/employeeController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

router.use(protect);
router.use(authorize('Admin'));

router.route('/')
  .get(getEmployees)
  .post(createEmployee);

router.get('/potential-managers', getPotentialManagers);

router.route('/:id')
  .get(getEmployeeById)
  .put(updateEmployee)
  .delete(deleteEmployee);

module.exports = router;
