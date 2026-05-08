const LeaveModel = require('../models/leaveModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

// @desc    Get current employee leave balance (current year)
// @route   GET /api/leaves/balance
// @access  Private
const getLeaveBalance = async (req, res, next) => {
    try {
        const year = req.query.year || new Date().getFullYear();
        const data = await LeaveModel.getBalance(req.user.employeeId, year);
        sendResponse(res, 200, 'Leave balance fetched successfully', data);
    } catch (error) { next(error); }
};

// @desc    Get leave types available for the employee
// @route   GET /api/leaves/types
// @access  Private
const getLeaveTypes = async (req, res, next) => {
    try {
        const data = await LeaveModel.getAvailableTypes(req.user.employeeId);
        sendResponse(res, 200, 'Leave types fetched successfully', data);
    } catch (error) { next(error); }
};

// @desc    Apply for leave
// @route   POST /api/leaves/apply
// @access  Private
const applyLeave = async (req, res, next) => {
    try {
        const { leave_type, start_date, end_date, total_days, leave_half_type, reason, attachment_path } = req.body;
        
        if (!leave_type || !start_date || !end_date || !total_days) {
            return next(new ErrorResponse('Please provide all required fields', 400));
        }

        const result = await LeaveModel.apply({
            employee_id: req.user.employeeId,
            leave_type,
            start_date,
            end_date,
            total_days,
            leave_half_type,
            reason,
            attachment_path
        });

        sendResponse(res, 201, 'Leave request submitted successfully', result);
    } catch (error) { next(error); }
};

// @desc    Get my leave requests
// @route   GET /api/leaves/my-requests
// @access  Private
const getMyRequests = async (req, res, next) => {
    try {
        const data = await LeaveModel.getMyRequests(req.user.employeeId);
        sendResponse(res, 200, 'Leave requests fetched successfully', data);
    } catch (error) { next(error); }
};

// @desc    Get subordinate requests for approval
// @route   GET /api/leaves/approvals
// @access  Private (HOD/Admin/Principal)
const getApprovals = async (req, res, next) => {
    try {
        const status = req.query.status || 'Pending';
        // If Admin, pass NULL to get all, else pass manager ID
        const managerId = ['Admin', 'Principal', 'super_admin'].includes(req.user.role) ? null : req.user.employeeId;
        
        const data = await LeaveModel.getApprovals(managerId, status);
        sendResponse(res, 200, 'Subordinate requests fetched successfully', data);
    } catch (error) { next(error); }
};

// @desc    Approve or Reject leave request
// @route   PUT /api/leaves/action/:id
// @access  Private (HOD/Admin/Principal)
const actionRequest = async (req, res, next) => {
    try {
        const { status, remarks } = req.body;
        const requestId = req.params.id;

        if (!['Approved', 'Rejected'].includes(status)) {
            return next(new ErrorResponse('Invalid status', 400));
        }

        const result = await LeaveModel.action(requestId, status, req.user.employeeId, remarks);
        
        if (result.affected_rows === 0) {
            return next(new ErrorResponse('Request not found', 404));
        }

        sendResponse(res, 200, `Request ${status.toLowerCase()} successfully`);
    } catch (error) { next(error); }
};

// @desc    Cancel a leave request
// @route   DELETE /api/leaves/:id
// @access  Private
const deleteRequest = async (req, res, next) => {
    try {
        const result = await LeaveModel.cancel(req.params.id, req.user.employeeId, req.user.role);
        
        if (result.affected_rows === 0) {
            return next(new ErrorResponse(result.message || 'Request not found', 404));
        }

        sendResponse(res, 200, 'Leave request cancelled successfully');
    } catch (error) { 
        if (error.message.includes('Not authorized') || error.message.includes('only cancel')) {
            return next(new ErrorResponse(error.message, 403));
        }
        next(error); 
    }
};

module.exports = {
    getLeaveBalance,
    getLeaveTypes,
    applyLeave,
    getMyRequests,
    getApprovals,
    actionRequest,
    deleteRequest
};
