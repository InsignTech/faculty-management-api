const DesignationModel = require('../models/designationModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const createDesignation = async (req, res, next) => {
  try {
    const { designation } = req.body;
    const created_by = req.user ? req.user.username : 'System';

    if (!designation) {
        return next(new ErrorResponse('Designation name is required', 400, 'VALIDATION_ERROR'));
    }
    const result = await DesignationModel.create(designation, created_by);
    sendResponse(res, 201, 'Designation created successfully', result);
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return next(new ErrorResponse('A designation with this name already exists', 400, 'DUPLICATE_ENTRY'));
    }
    next(error);
  }
};

const getDesignations = async (req, res, next) => {
  try {
    const designations = await DesignationModel.getAll();
    sendResponse(res, 200, 'Designations fetched successfully', designations);
  } catch (error) {
    next(error);
  }
};

const getDesignationById = async (req, res, next) => {
  try {
    const designation = await DesignationModel.getById(req.params.id);
    if (!designation) {
      return next(new ErrorResponse('Designation not found', 404, 'NOT_FOUND'));
    }
    sendResponse(res, 200, 'Designation fetched successfully', designation);
  } catch (error) {
    next(error);
  }
};

const updateDesignation = async (req, res, next) => {
  try {
    const { designation } = req.body;
    const result = await DesignationModel.update(req.params.id, designation);
    if (result && result.affected_rows === 0) {
      return next(new ErrorResponse('Designation not found', 404, 'NOT_FOUND'));
    }
    sendResponse(res, 200, 'Designation updated successfully', result);
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return next(new ErrorResponse('A designation with this name already exists', 400, 'DUPLICATE_ENTRY'));
    }
    next(error);
  }
};

const deleteDesignation = async (req, res, next) => {
  try {
    await DesignationModel.delete(req.params.id);
    sendResponse(res, 200, 'Designation deleted successfully');
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createDesignation,
  getDesignations,
  getDesignationById,
  updateDesignation,
  deleteDesignation,
};
