const express = require('express');
const router = express.Router();
const {
  getSystemPolicies,
  createSystemPolicy,
  updateSystemPolicy,
  setActiveSystemPolicy,
  deleteSystemPolicy,
  getRolePolicy,
  saveRolePolicy,
  getEmployeePolicy,
  saveEmployeePolicy,
  getEffectivePolicy,
  calculateAccrual,
  getPolicyHistory
} = require('../controllers/leavePolicyController');

// System Level
router.get('/system', getSystemPolicies);
router.post('/system', createSystemPolicy);
router.put('/system/:id', updateSystemPolicy);
router.put('/system/:id/activate', setActiveSystemPolicy);
router.delete('/system/:id', deleteSystemPolicy);
router.get('/history', getPolicyHistory);
router.get('/history/:id', getPolicyHistory);

// Role Level
router.get('/role/:id', getRolePolicy);
router.post('/role', saveRolePolicy);

// Employee Level
router.get('/employee/:id', getEmployeePolicy);
router.post('/employee', saveEmployeePolicy);

// Effective Policy (Merged)
router.get('/effective/:id', getEffectivePolicy);

// Job / Manual Trigger
router.post('/calculate-accrual', calculateAccrual);

module.exports = router;
