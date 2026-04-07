const LeaveEncashmentModel = require('../models/leaveEncashmentModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const requestLeaveEncashment = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) return next(new ErrorResponse('User is not associated with an employee record', 400));
        
        const { leave_type, days } = req.body;
        if (!leave_type || !days) return next(new ErrorResponse('leave_type and days are required', 400));
        
        const result = await LeaveEncashmentModel.request(employeeId, leave_type, days);
        sendResponse(res, 201, 'Leave encashment request submitted successfully', result);
    } catch (error) { next(error); }
};

const getMyLeaveEncashments = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) return next(new ErrorResponse('User is not associated with an employee record', 400));
        
        const history = await LeaveEncashmentModel.getHistory(employeeId);
        sendResponse(res, 200, 'Leave encashment history fetched', history);
    } catch (error) { next(error); }
};

const getPendingEncashments = async (req, res, next) => {
    try {
        const pending = await LeaveEncashmentModel.getAllPending();
        sendResponse(res, 200, 'Pending leave encashments fetched', pending);
    } catch (error) { next(error); }
};

module.exports = { requestLeaveEncashment, getMyLeaveEncashments, getPendingEncashments };
