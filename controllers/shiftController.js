const ShiftModel = require('../models/shiftModel');
const pool = require('../config/db');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');
const { interceptApproval } = require('../utils/approvalInterceptor');

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

    const requesterId = req.user.employeeId || req.user.employee_id;
    const originalData = await ShiftModel.getGlobalShiftById(id);

    const execute = async () => {
      const result = await ShiftModel.updateGlobalShift(id, {
        start_time,
        end_time,
        start_grace_mins,
        end_grace_mins,
        modified_by: req.user.name || 'admin'
      });
      return result;
    };

    const interceptResult = await interceptApproval({
      requestType: 'SHIFT',
      actionType: 'UPDATE',
      entityId: id,
      requestedData: req.body,
      originalData,
      requesterId,
      requesterRole: req.user?.role,
      user: req.user,
      executeCallback: execute
    });

    if (interceptResult.pendingApproval) {
      return sendResponse(res, 202, interceptResult.message, { pendingApproval: true });
    }

    if (!interceptResult.result) {
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

    const requesterId = req.user.employeeId || req.user.employee_id;

    const execute = async () => {
      const results = await ShiftModel.assignShiftRequest({
        employee_id,
        role_id,
        from_date,
        to_date,
        shifts,
        modified_by: req.user.name || 'admin'
      });
      
      const targetEmployeeIdsCount = results.length;
      if (targetEmployeeIdsCount === 0) {
        throw new ErrorResponse('No active employees found for the selected roles', 400);
      }
      const overlapCount = results.filter(r => !r.success).length;
      return { results, targetEmployeeIdsCount, overlapCount };
    };

    const interceptResult = await interceptApproval({
      requestType: 'SHIFT',
      actionType: 'ASSIGN',
      entityId: employee_id || null,
      requestedData: {
        employee_id,
        role_id,
        from_date,
        to_date,
        shifts,
        modified_by: req.user.name || 'admin'
      },
      originalData: null,
      requesterId,
      requesterRole: req.user?.role,
      user: req.user,
      executeCallback: execute
    });

    if (interceptResult.pendingApproval) {
      return sendResponse(res, 202, interceptResult.message, { pendingApproval: true });
    }

    const { results, targetEmployeeIdsCount, overlapCount } = interceptResult.result;
    sendResponse(res, 201, `Shift assigned to ${targetEmployeeIdsCount - overlapCount} employees. (${overlapCount} skipped due to overlap).`, { results });
  } catch (error) {
    next(error);
  }
};

const deleteEmployeeShiftGroup = async (req, res, next) => {
    try {
        const { employee_id, start_date, end_date } = req.body;
        const requesterId = req.user.employeeId || req.user.employee_id;

        const execute = async () => {
            const affectedRows = await ShiftModel.deleteEmployeeShiftGroup(employee_id, start_date, end_date);
            return affectedRows;
        };

        const interceptResult = await interceptApproval({
            requestType: 'SHIFT',
            actionType: 'DELETE',
            entityId: employee_id,
            requestedData: {
                employee_id,
                start_date,
                end_date
            },
            originalData: null,
            requesterId,
            requesterRole: req.user?.role,
            user: req.user,
            executeCallback: execute
        });

        if (interceptResult.pendingApproval) {
            return sendResponse(res, 202, interceptResult.message, { pendingApproval: true });
        }

        if (interceptResult.result === 0) {
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
    const requesterId = req.user.employeeId || req.user.employee_id;

    if (!date && (!role_id || role_id === 'all')) {
      return next(new ErrorResponse('Please specify at least a date or a specific role to delete shifts in bulk', 400));
    }

    const execute = async () => {
      const deletedCount = await ShiftModel.deleteBulkShifts({ date, role_id });
      return deletedCount;
    };

    const interceptResult = await interceptApproval({
      requestType: 'SHIFT',
      actionType: 'DELETE_BULK',
      entityId: null,
      requestedData: {
        date,
        role_id
      },
      originalData: null,
      requesterId,
      requesterRole: req.user?.role,
      user: req.user,
      executeCallback: execute
    });

    if (interceptResult.pendingApproval) {
      return sendResponse(res, 202, interceptResult.message, { pendingApproval: true });
    }

    sendResponse(res, 200, `${interceptResult.result} shifts deleted successfully`, { deletedCount: interceptResult.result });
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
