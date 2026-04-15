const express = require('express');
const { 
    getExceptionalDays, 
    saveExceptionalDay, 
    deleteExceptionalDay 
} = require('../controllers/exceptionalController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

router.use(protect);

// All users can view the exceptional days master list
router.get('/', getExceptionalDays);

// Only Admin/Principal can manage the master list
router.post('/', authorize('Admin', 'Principal', 'super_admin'), saveExceptionalDay);
router.delete('/:id', authorize('Admin', 'Principal', 'super_admin'), deleteExceptionalDay);

module.exports = router;
