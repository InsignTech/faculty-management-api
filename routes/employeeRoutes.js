const express = require('express');
const {
  createEmployee,
  getEmployees,
  getPotentialManagers,
  getEmployeeById,
  getMe,
  updateEmployee,
  deleteEmployee,
  updateReportingManager,
  getSubordinates,
  updateProfilePicture,
  uploadDocument,
  searchSubstitutes,
  getAvailableSubstitutes,
} = require('../controllers/employeeController');
const { protect, authorize } = require('../middleware/auth');
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() });

const router = express.Router();

router.use(protect);

router.get('/', getEmployees);
router.post('/', authorize('Admin', 'admin', 'principal', 'super_admin', 'Operations Manager', 'operations manager'), createEmployee);

router.get('/potential-managers', authorize('Admin', 'admin', 'principal', 'super_admin', 'HOD', 'hod', 'Operations Manager', 'operations manager'), getPotentialManagers);
router.get('/subordinates', authorize('Admin', 'admin', 'principal', 'super_admin', 'HOD', 'hod', 'Operations Manager', 'operations manager'), getSubordinates);
router.get('/search-substitute', searchSubstitutes); // Global search for any employee (used in substitute picker)
router.get('/available-substitutes', getAvailableSubstitutes);

router.get('/me', getMe);
router.post('/profile-picture', upload.single('profile_picture'), updateProfilePicture);
router.post('/upload-document', upload.single('document'), uploadDocument);

router.get('/:id', authorize('Admin', 'admin', 'principal', 'super_admin', 'HOD', 'hod', 'Operations Manager', 'operations manager'), getEmployeeById);
router.put('/:id', authorize('Admin', 'admin', 'principal', 'super_admin', 'Operations Manager', 'operations manager'), updateEmployee);
router.delete('/:id', authorize('Admin', 'admin', 'principal', 'super_admin', 'Operations Manager', 'operations manager'), deleteEmployee);

router.put('/:id/manager', authorize('Admin', 'admin', 'principal', 'super_admin', 'HOD', 'hod', 'Operations Manager', 'operations manager'), updateReportingManager);

module.exports = router;
