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
} = require('../controllers/employeeController');
const { protect, authorize } = require('../middleware/auth');
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() });

const router = express.Router();

router.use(protect);

router.get('/', getEmployees);
router.post('/', authorize('Admin', 'admin', 'principal', 'super_admin'), createEmployee);

router.get('/potential-managers', authorize('Admin', 'admin', 'principal', 'super_admin', 'HOD', 'hod'), getPotentialManagers);
router.get('/subordinates', authorize('Admin', 'admin', 'principal', 'super_admin', 'HOD', 'hod'), getSubordinates);

router.get('/me', getMe);
router.post('/profile-picture', upload.single('profile_picture'), updateProfilePicture);
router.post('/upload-document', upload.single('document'), uploadDocument);

router.get('/:id', authorize('Admin', 'admin', 'principal', 'super_admin', 'HOD', 'hod'), getEmployeeById);
router.put('/:id', authorize('Admin', 'admin', 'principal', 'super_admin'), updateEmployee);
router.delete('/:id', authorize('Admin', 'admin', 'principal', 'super_admin'), deleteEmployee);

router.put('/:id/manager', authorize('Admin', 'admin', 'principal', 'super_admin', 'HOD', 'hod'), updateReportingManager);

module.exports = router;
