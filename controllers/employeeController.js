const bcrypt = require('bcryptjs');
const EmployeeModel = require('../models/employeeModel');
const UserModel = require('../models/userModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');
const { sendWelcomeEmail } = require('../utils/emailService');

const createEmployee = async (req, res, next) => {
  try {
    const { email, employee_name, role_id, employee_code } = req.body;
    
    // 1. Mandatory Validation
    if (!email || !employee_code || !employee_name) {
        return next(new ErrorResponse('Email, Employee Name and Code are mandatory!', 400, 'VALIDATION_ERROR'));
    }

    // First create the employee record
    const result = await EmployeeModel.create(req.body);
    
    if (result && result.employee_id) {
        // Generate a random temporary password
        const tempPassword = Math.random().toString(36).slice(-8);
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(tempPassword, salt);
        
        // Create user account linked to this employee
        await UserModel.signup(
            employee_name, 
            email, 
            hashedPassword, 
            role_id || 1, 
            result.employee_id
        );
        
        // Send welcome email with credentials
        try {
            await sendWelcomeEmail({ toEmail: email, employeeName: employee_name, tempPassword });
            console.log(`Welcome email sent to: ${email}`);
        } catch (emailErr) {
            console.error(`Failed to send welcome email to ${email}:`, emailErr.message);
        }
    }

    sendResponse(res, 201, 'Employee created successfully with user account', result);
  } catch (error) {
    // Check for MySQL duplicate key error (ER_DUP_ENTRY)
    if (error.code === 'ER_SIGNAL_NOT_FOUND' || error.sqlState === '45000') {
        return next(new ErrorResponse(error.message, 409, 'CONFLICT'));
    }
    next(error);
  }
};

const getEmployees = async (req, res, next) => {
  try {
    const { search, role } = req.query;
    if (search || role) {
      const employees = await EmployeeModel.getFiltered(search, role);
      return sendResponse(res, 200, 'Employees fetched successfully', employees);
    }
    const employees = await EmployeeModel.getAll();
    sendResponse(res, 200, 'Employees fetched successfully', employees);
  } catch (error) {
    next(error);
  }
};

const getPotentialManagers = async (req, res, next) => {
  try {
    const { search, department, excludeId } = req.query;
    const managers = await EmployeeModel.getPotentialManagers(
      search || '',
      department || 0,
      excludeId || 0
    );
    sendResponse(res, 200, 'Potential managers fetched successfully', managers);
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

const updateReportingManager = async (req, res, next) => {
  try {
    const { manager_id } = req.body;
    const result = await EmployeeModel.updateReportingManager(req.params.id, manager_id);
    if (result && result.affectedRows === 0) {
      return next(new ErrorResponse('Employee not found', 404, 'NOT_FOUND'));
    }
    sendResponse(res, 200, 'Reporting manager updated successfully');
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createEmployee,
  getEmployees,
  getPotentialManagers,
  getEmployeeById,
  updateEmployee,
  deleteEmployee,
  updateReportingManager,
};
