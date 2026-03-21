const express = require('express');
const router = express.Router();
const { getRolePrivileges, saveRolePrivileges } = require('../controllers/privilageController');
const { protect } = require('../middleware/auth');

router.get('/:roleId', protect, getRolePrivileges);
router.post('/', protect, saveRolePrivileges);

module.exports = router;
