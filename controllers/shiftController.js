const ShiftModel = require('../models/shiftModel');
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
    const { search, page = 1, limit = 30 } = req.query; // Default to 30 rows (10 assignments)
    const { shifts, total } = await ShiftModel.getAllEmployeeShifts({ 
      search, 
      page: parseInt(page), 
      limit: parseInt(limit) 
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
    const { employee_id, from_date, to_date, shifts } = req.body;

    if (!employee_id || !from_date || !shifts || shifts.length !== 3) {
      return next(new ErrorResponse('Employee ID, From Date, and 3 mandatory shift entries are required', 400));
    }

    // Date validation
    if (to_date && new Date(to_date) < new Date(from_date)) {
        return next(new ErrorResponse('To Date cannot be before From Date', 400));
    }

    await ShiftModel.assignEmployeeShifts(
      employee_id,
      from_date,
      to_date,
      shifts,
      req.user.name || 'admin'
    );

    sendResponse(res, 201, 'Shift assigned successfully to employee');
  } catch (error) {
    if (error.message.includes('overlaps')) {
        return next(new ErrorResponse(error.message, 400, 'OVERLAP_ERROR'));
    }
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

module.exports = {
  getGlobalShifts,
  getAllEmployeeShifts,
  updateGlobalShift,
  assignEmployeeShift,
  deleteEmployeeShiftGroup
};
