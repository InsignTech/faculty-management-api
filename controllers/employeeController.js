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

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        return next(new ErrorResponse('Please provide a valid email address!', 400, 'VALIDATION_ERROR'));
    }

    // The account creation is now handled inside EmployeeModel.create
    const result = await EmployeeModel.create(req.body);
    
    // Send welcome email if creation was successful
    if (result && result.employee_id && email) {
        try {
            // Default password pattern used in Model: [EmployeeCode]@123
            const tempPassword = `${employee_code || 'User'}@123`;
            await sendWelcomeEmail({ toEmail: email, employeeName: employee_name, tempPassword });
            console.log(`Welcome email sent to: ${email}`);
        } catch (emailErr) {
            console.error(`Failed to send welcome email to ${email}:`, emailErr.message);
        }
    }

    sendResponse(res, 201, 'Employee created successfully', result);
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
    const { search, role, page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    const userRole = req.user.role?.toLowerCase();
    const isAdmin = ['admin', 'super_admin', 'principal'].includes(userRole);
    
    let managerId = 0;
    let myManagerId = 0;

    if (!isAdmin) {
      const myId = req.user.employeeId || 0;
      managerId = myId;
      
      const currentUserEmp = await EmployeeModel.getById(myId);
      myManagerId = currentUserEmp?.reporting_manager_id || 0;
    }

    const [employees, total] = await Promise.all([
      EmployeeModel.getFiltered(search, role, parseInt(limit), parseInt(offset), managerId, myManagerId),
      EmployeeModel.getTotalCount(search, role, managerId, myManagerId)
    ]);

    sendResponse(res, 200, 'Employees fetched successfully', {
      employees,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / limit)
      }
    });
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

const getMe = async (req, res, next) => {
  try {
    const myId = req.user.employeeId;
    if (!myId) {
      return next(new ErrorResponse('Employee ID not found in token', 400, 'BAD_REQUEST'));
    }
    const employee = await EmployeeModel.getById(myId);
    if (!employee) {
      return next(new ErrorResponse('Employee not found', 404, 'NOT_FOUND'));
    }
    sendResponse(res, 200, 'Profile fetched successfully', employee);
  } catch (error) {
    next(error);
  }
};

const updateEmployee = async (req, res, next) => {
  try {
    const { email } = req.body;
    if (email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return next(new ErrorResponse('Please provide a valid email address!', 400, 'VALIDATION_ERROR'));
        }
    }

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

const getSubordinates = async (req, res, next) => {
  try {
    const managerId = req.user.employeeId;
    if (!managerId) {
      return next(new ErrorResponse('User is not associated with an employee record', 400, 'MISSING_EMPLOYEE_RECORD'));
    }
    const subordinates = await EmployeeModel.getSubordinates(managerId);
    sendResponse(res, 200, 'Subordinates fetched successfully', subordinates);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createEmployee,
  getEmployees,
  getPotentialManagers,
  getEmployeeById,
  getMe,
  updateEmployee,
  deleteEmployee,
  updateReportingManager,
  getSubordinates,
};
