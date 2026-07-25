const ShiftModel = require('../models/shiftModel');
const pool = require('../config/db');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const getGlobalShifts = async (req, res, next) => {
  try {
    const shifts = await ShiftModel.getGlobalShifts();
    sendResponse(res, 200, 'Global shifts fetched successfully', shifts);
  } catch (error) {
    next(error);
  }
};

const getAllEmployeeShifts = async (req, res, next) => {
  try {
    const { search, page = 1, limit = 30, role_id, date } = req.query; // Default to 30 rows (10 assignments)
    const { shifts, total } = await ShiftModel.getAllEmployeeShifts({ 
      search, 
      page: parseInt(page), 
      limit: parseInt(limit),
      role_id,
      date
    });
    sendResponse(res, 200, 'Employee shifts fetched successfully', { shifts, total });
  } catch (error) {
    next(error);
  }
};

const updateGlobalShift = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { start_time, end_time, start_grace_mins, end_grace_mins } = req.body;
    
    if (!start_time || !end_time) {
      return next(new ErrorResponse('Start and End times are required', 400));
    }

    const result = await ShiftModel.updateGlobalShift(id, {
      start_time,
      end_time,
      start_grace_mins,
      end_grace_mins,
      modified_by: req.user.name || 'admin'
    });

    if (!result) {
      return next(new ErrorResponse('Global shift not found', 404));
    }

    sendResponse(res, 200, 'Global shift updated successfully');
  } catch (error) {
    next(error);
  }
};

const assignEmployeeShift = async (req, res, next) => {
  try {
    const { employee_id, role_id, from_date, to_date, shifts } = req.body;

    if ((!employee_id && !role_id) || !from_date || !shifts || shifts.length !== 3) {
      return next(new ErrorResponse('Employee ID or Role ID, From Date, and 3 mandatory shift entries are required', 400));
    }

    // Date validation
    if (to_date && new Date(to_date) < new Date(from_date)) {
        return next(new ErrorResponse('To Date cannot be before From Date', 400));
    }

    let targetEmployeeIds = [];
    if (employee_id) {
      targetEmployeeIds.push(employee_id);
    } else if (role_id) {
      const roleIds = Array.isArray(role_id) ? role_id : [role_id];
      const activeRoleIds = roleIds.filter(id => id && id !== 'all');
      
      if (activeRoleIds.length > 0) {
        const [rows] = await pool.query('SELECT employee_id FROM employee WHERE role_id IN (?) AND active = 1', [activeRoleIds]);
        targetEmployeeIds = rows.map(r => r.employee_id);
      }
    }

    if (targetEmployeeIds.length === 0) {
      return next(new ErrorResponse('No active employees found for the selected roles', 400));
    }

    const results = [];
    let overlapCount = 0;
    for (const emp_id of targetEmployeeIds) {
      try {
        await ShiftModel.assignEmployeeShifts(
          emp_id,
          from_date,
          to_date,
          shifts,
          req.user.name || 'admin'
        );
        results.push({ employee_id: emp_id, success: true });
      } catch (error) {
        if (error.message.includes('overlaps')) {
          overlapCount++;
          results.push({ employee_id: emp_id, success: false, reason: 'Overlap error' });
        } else {
          throw error;
        }
      }
    }

    sendResponse(res, 201, `Shift assigned to ${targetEmployeeIds.length - overlapCount} employees. (${overlapCount} skipped due to overlap).`, { results });
  } catch (error) {
    next(error);
  }
};

const deleteEmployeeShiftGroup = async (req, res, next) => {
    try {
        const { employee_id, start_date, end_date } = req.body;
        const affectedRows = await ShiftModel.deleteEmployeeShiftGroup(employee_id, start_date, end_date);
        
        if (affectedRows === 0) {
            return next(new ErrorResponse('No matching shift assignment found to delete', 404));
        }

        sendResponse(res, 200, 'Shift group deleted successfully');
    } catch (error) {
        next(error);
    }
};

const deleteBulkShifts = async (req, res, next) => {
  try {
    const { date, role_id } = req.query;

    if (!date && (!role_id || role_id === 'all')) {
      return next(new ErrorResponse('Please specify at least a date or a specific role to delete shifts in bulk', 400));
    }

    const deletedCount = await ShiftModel.deleteBulkShifts({ date, role_id });
    sendResponse(res, 200, `${deletedCount} shifts deleted successfully`, { deletedCount });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getGlobalShifts,
  getAllEmployeeShifts,
  updateGlobalShift,
  assignEmployeeShift,
  deleteEmployeeShiftGroup,
  deleteBulkShifts
};
