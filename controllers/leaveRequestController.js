const LeaveRequestModel = require('../models/leaveRequestModel');
const { sendResponse } = require('../utils/responseHelper');

const getLeaveRequests = async (req, res, next) => {
  try {
    const filters = {
      status: req.query.status,
      employee_id: req.query.employee_id
    };
    const requests = await LeaveRequestModel.getAll(filters);
    sendResponse(res, 200, 'Leave requests fetched successfully', requests);
  } catch (error) {
    next(error);
  }
};

const updateRequestStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, rejection_reason } = req.body;
    const approved_by_id = req.user?.id || 1; // Fallback for dev

    await LeaveRequestModel.updateStatus(id, status, { approved_by_id, rejection_reason });
    sendResponse(res, 200, `Request ${status} successfully`);
  } catch (error) {
    next(error);
  }
};

const getEmployeeBalance = async (req, res, next) => {
  try {
    const { employeeId } = req.params;
    const balance = await LeaveRequestModel.getLeaveBalance(employeeId);
    sendResponse(res, 200, 'Leave balance fetched successfully', balance);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getLeaveRequests,
  updateRequestStatus,
  getEmployeeBalance
};
