const EmployeeModel = require('../models/employeeModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const createEmployee = async (req, res, next) => {
  try {
    const result = await EmployeeModel.create(req.body);
    sendResponse(res, 201, 'Employee created successfully', result);
  } catch (error) {
    next(error);
  }
};

const getEmployees = async (req, res, next) => {
  try {
    const employees = await EmployeeModel.getAll();
    sendResponse(res, 200, 'Employees fetched successfully', employees);
  } catch (error) {
    next(error);
  }
};

const getEmployeeById = async (req, res, next) => {
  try {
    const employee = await EmployeeModel.getById(req.params.id);
    if (!employee) {
      return next(new ErrorResponse('Employee not found', 404, 'NOT_FOUND'));
    }
    sendResponse(res, 200, 'Employee fetched successfully', employee);
  } catch (error) {
    next(error);
  }
};

const updateEmployee = async (req, res, next) => {
  try {
    const result = await EmployeeModel.update(req.params.id, req.body);
    if (result && result.affected_rows === 0) {
      return next(new ErrorResponse('Employee not found', 404, 'NOT_FOUND'));
    }
    sendResponse(res, 200, 'Employee updated successfully', result);
  } catch (error) {
    next(error);
  }
};

const deleteEmployee = async (req, res, next) => {
  try {
    await EmployeeModel.delete(req.params.id);
    sendResponse(res, 200, 'Employee deleted successfully');
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createEmployee,
  getEmployees,
  getEmployeeById,
  updateEmployee,
  deleteEmployee,
};
