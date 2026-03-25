const express = require('express');
const {
  createDesignation,
  getDesignations,
  getDesignationById,
  updateDesignation,
  deleteDesignation,
} = require('../controllers/designationController');
const { protect, authorize } = require('../middleware/auth');
const router = express.Router();

/**
 * @swagger
 * tags:
 *   name: Designations
 *   description: Designation management API
 */

/**
 * @swagger
 * /api/designations:
 *   post:
 *     summary: Create a new designation
 *     tags: [Designations]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [designation]
 *             properties:
 *               designation: { type: string }
 *     responses:
 *       201:
 *         description: Designation created successfully
 *       403:
 *         description: Forbidden
 */
router.post('/', protect, authorize('Admin'), createDesignation);

/**
 * @swagger
 * /api/designations:
 *   get:
 *     summary: Get all designations
 *     tags: [Designations]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of all designations
 */
router.get('/', protect, getDesignations);

/**
 * @swagger
 * /api/designations/{id}:
 *   get:
 *     summary: Get designation by ID
 *     tags: [Designations]
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
 *         description: Designation details
 *       404:
 *         description: Designation not found
 */
router.get('/:id', protect, getDesignationById);

/**
 * @swagger
 * /api/designations/{id}:
 *   put:
 *     summary: Update a designation
 *     tags: [Designations]
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
 *               designation: { type: string }
 *     responses:
 *       200:
 *         description: Designation updated successfully
 */
router.put('/:id', protect, authorize('Admin'), updateDesignation);

/**
 * @swagger
 * /api/designations/{id}:
 *   delete:
 *     summary: Delete a designation
 *     tags: [Designations]
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
 *         description: Designation deleted successfully
 */
router.delete('/:id', protect, authorize('Admin'), deleteDesignation);

module.exports = router;
