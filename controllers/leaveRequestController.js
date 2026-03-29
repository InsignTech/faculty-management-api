const LeaveRequestModel = require('../models/leaveRequestModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const getLeaveBalance = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) {
            return next(new ErrorResponse('User is not associated with an employee record', 400));
        }

        const year = req.query.year || new Date().getFullYear();
        const balance = await LeaveRequestModel.getLeaveBalance(employeeId, year);
        
        sendResponse(res, 200, 'Leave balance fetched successfully', balance);
    } catch (error) {
        next(error);
    }
};

const applyLeave = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) {
            return next(new ErrorResponse('User is not associated with an employee record', 400));
        }

        const { leave_type, start_date, end_date, reason, attachment_path } = req.body;

        if (!leave_type || !start_date || !end_date) {
            return next(new ErrorResponse('Please provide leave type, start date and end date', 400));
        }

        // Calculate total days
        const start = new Date(start_date);
        const end = new Date(end_date);
        const diffTime = Math.abs(end - start);
        const total_days = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;

        const result = await LeaveRequestModel.applyLeave({
            employee_id: employeeId,
            leave_type,
            start_date,
            end_date,
            total_days,
            reason,
            attachment_path
        });

        sendResponse(res, 201, 'Leave application submitted successfully', result);
    } catch (error) {
        next(error);
    }
};

const getEmployeeLeaves = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) {
            return next(new ErrorResponse('User is not associated with an employee record', 400));
        }

        const leaves = await LeaveRequestModel.getEmployeeLeaves(employeeId);
        sendResponse(res, 200, 'Leave history fetched successfully', leaves);
    } catch (error) {
        next(error);
    }
};

module.exports = {
    getLeaveBalance,
    applyLeave,
    getEmployeeLeaves
};
