const DepartmentModel = require('../models/departmentModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const createDepartment = async (req, res, next) => {
  try {
    const { departmentname } = req.body;
    if (!departmentname) {
        return next(new ErrorResponse('Department name is required', 400, 'VALIDATION_ERROR'));
    }
    const result = await DepartmentModel.create(departmentname);
    sendResponse(res, 201, 'Department created successfully', result);
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return next(new ErrorResponse('A department with this name already exists', 400, 'DUPLICATE_ENTRY'));
    }
    next(error);
  }
};

const getDepartments = async (req, res, next) => {
  try {
    const departments = await DepartmentModel.getAll();
    sendResponse(res, 200, 'Departments fetched successfully', departments);
  } catch (error) {
    next(error);
  }
};

const getDepartmentById = async (req, res, next) => {
  try {
    const department = await DepartmentModel.getById(req.params.id);
    if (!department) {
      return next(new ErrorResponse('Department not found', 404, 'NOT_FOUND'));
    }
    sendResponse(res, 200, 'Department fetched successfully', department);
  } catch (error) {
    next(error);
  }
};

const updateDepartment = async (req, res, next) => {
  try {
    const { departmentname } = req.body;
    const result = await DepartmentModel.update(req.params.id, departmentname);
    if (result && result.affected_rows === 0) {
      return next(new ErrorResponse('Department not found', 404, 'NOT_FOUND'));
    }
    sendResponse(res, 200, 'Department updated successfully', result);
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return next(new ErrorResponse('A department with this name already exists', 400, 'DUPLICATE_ENTRY'));
    }
    next(error);
  }
};

const deleteDepartment = async (req, res, next) => {
  try {
    await DepartmentModel.delete(req.params.id);
    sendResponse(res, 200, 'Department deleted successfully');
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createDepartment,
  getDepartments,
  getDepartmentById,
  updateDepartment,
  deleteDepartment,
};
