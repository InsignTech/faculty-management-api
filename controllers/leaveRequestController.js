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
    const approved_by_id = req.user?.employeeId || req.user?.id || 1;

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

const createLeaveRequest = async (req, res, next) => {
  try {
    const result = await LeaveRequestModel.create(req.body);
    sendResponse(res, 201, 'Leave application submitted successfully', result);
  } catch (error) {
    next(error);
  }
};

const getTeamRequests = async (req, res, next) => {
  try {
    // JWT payload uses camelCase 'employeeId' (set in authController.login)
    const superiorId = req.user?.employeeId;
    console.log(`[Team Requests] JWT user:`, req.user, '→ superiorId:', superiorId);

    if (!superiorId) {
      return sendResponse(res, 200, 'No team found (user has no linked employee record)', []);
    }

    const requests = await LeaveRequestModel.getForSuperior(superiorId);
    sendResponse(res, 200, 'Team leave requests fetched successfully', requests);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getLeaveRequests,
  createLeaveRequest,
  getTeamRequests,
  updateRequestStatus,
  getEmployeeBalance
};
