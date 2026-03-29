const express = require('express');
const router = express.Router();
const {
  getSystemPolicies,
  createSystemPolicy,
  updateSystemPolicy,
  setActiveSystemPolicy,
  deleteSystemPolicy,
  getDesignationPolicy,
  saveDesignationPolicy,
  getEmployeePolicy,
  saveEmployeePolicy
} = require('../controllers/leavePolicyController');

// System Level
router.get('/system', getSystemPolicies);
router.post('/system', createSystemPolicy);
router.put('/system/:id', updateSystemPolicy);
router.put('/system/:id/activate', setActiveSystemPolicy);
router.delete('/system/:id', deleteSystemPolicy);

// Designation Level
router.get('/designation/:id', getDesignationPolicy);
router.post('/designation', saveDesignationPolicy);

// Employee Level
router.get('/employee/:id', getEmployeePolicy);
router.post('/employee', saveEmployeePolicy);

module.exports = router;
