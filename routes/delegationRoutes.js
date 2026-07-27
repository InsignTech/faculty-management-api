const express = require('express');
const {
  createDelegation,
  deleteDelegation,
  getDelegations,
  getMyDelegatedTargets
} = require('../controllers/delegationController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

// All routes require authentication
router.use(protect);

// Endpoint for form autocomplete (any authenticated employee can fetch their own delegated targets)
router.get('/my-targets', getMyDelegatedTargets);

// Configuration routes (restricted to Admin, Principal, or Super Admin roles)
router.post('/', authorize('Admin', 'Principal', 'super_admin', 'superAdmin'), createDelegation);
router.delete('/:id', authorize('Admin', 'Principal', 'super_admin', 'superAdmin'), deleteDelegation);
router.get('/', authorize('Admin', 'Principal', 'super_admin', 'superAdmin'), getDelegations);

module.exports = router;
