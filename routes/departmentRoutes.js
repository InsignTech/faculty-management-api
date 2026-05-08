const express = require('express');
const {
  createDepartment,
  getDepartments,
  getDepartmentById,
  updateDepartment,
  deleteDepartment,
} = require('../controllers/departmentController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

/**
 * @swagger
 * tags:
 *   name: Departments
 *   description: Department management API
 */

/**
 * @swagger
 * /api/departments:
 *   post:
 *     summary: Create a new department
 *     tags: [Departments]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [departmentname]
 *             properties:
 *               departmentname: { type: string }
 *     responses:
 *       201:
 *         description: Department created successfully
 *       403:
 *         description: Forbidden
 */
router.post('/', protect, authorize('Admin', 'principal', 'super_admin'), createDepartment);

/**
 * @swagger
 * /api/departments:
 *   get:
 *     summary: Get all departments
 *     tags: [Departments]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of all departments
 */
router.get('/', protect, getDepartments);

/**
 * @swagger
 * /api/departments/{id}:
 *   get:
 *     summary: Get department by ID
 *     tags: [Departments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Department details
 *       404:
 *         description: Department not found
 */
router.get('/:id', protect, getDepartmentById);

/**
 * @swagger
 * /api/departments/{id}:
 *   put:
 *     summary: Update a department
 *     tags: [Departments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               departmentname: { type: string }
 *     responses:
 *       200:
 *         description: Department updated successfully
 */
router.put('/:id', protect, authorize('Admin', 'principal', 'super_admin'), updateDepartment);

/**
 * @swagger
 * /api/departments/{id}:
 *   delete:
 *     summary: Delete a department
 *     tags: [Departments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Department deleted successfully
 */
router.delete('/:id', protect, authorize('Admin', 'principal', 'super_admin'), deleteDepartment);

module.exports = router;
