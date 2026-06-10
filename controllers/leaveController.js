const LeaveModel = require('../models/leaveModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

// @desc    Get current employee leave balance
// @route   GET /api/leaves/balance
const getLeaveBalance = async (req, res, next) => {
    try {
        const year = req.query.year || new Date().getFullYear();
        const data = await LeaveModel.getBalance(req.user.employeeId, year);
        sendResponse(res, 200, 'Leave balance fetched successfully', data);
    } catch (error) { next(error); }
};

// @desc    Get leave types available for the employee
// @route   GET /api/leaves/types
const getLeaveTypes = async (req, res, next) => {
    try {
        const data = await LeaveModel.getAvailableTypes(req.user.employeeId);
        sendResponse(res, 200, 'Leave types fetched successfully', data);
    } catch (error) { next(error); }
};

// @desc    Apply for leave (supports substitute_employee_id)
// @route   POST /api/leaves/apply
const applyLeave = async (req, res, next) => {
    try {
        const {
            leave_type, start_date, end_date, total_days,
            leave_half_type, reason, attachment_path,
            substitute_employee_id
        } = req.body;

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
            attachment_path,
            substitute_employee_id: substitute_employee_id || null
        });

        sendResponse(res, 201, 'Leave request submitted successfully', result);
    } catch (error) { next(error); }
};

// @desc    Get my leave requests (includes approver + substitute info)
// @route   GET /api/leaves/my-requests
const getMyRequests = async (req, res, next) => {
    try {
        const data = await LeaveModel.getMyRequests(req.user.employeeId);
        sendResponse(res, 200, 'Leave requests fetched successfully', data);
    } catch (error) { next(error); }
};

// @desc    Get subordinate requests for approval
// @route   GET /api/leaves/approvals
const getApprovals = async (req, res, next) => {
    try {
        const status = req.query.status || 'Pending';
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        // Admin/Principal/super_admin see all; others see only their approval queue
        const isAdmin = ['Admin', 'Principal', 'super_admin'].includes(req.user.role);
        const managerId = isAdmin ? null : req.user.employeeId;

        const data = await LeaveModel.getApprovals(managerId, status, page, limit);
        const total = await LeaveModel.getApprovalsCount(managerId, status);
        sendResponse(res, 200, 'Approval requests fetched successfully', { requests: data, total });
    } catch (error) { next(error); }
};

// @desc    Approve or Reject leave request (2-level aware)
// @route   PUT /api/leaves/action/:id
const actionRequest = async (req, res, next) => {
    try {
        const { status, remarks, substitute_employee_id } = req.body;
        const requestId = req.params.id;

        if (!['Approved', 'Rejected'].includes(status)) {
            return next(new ErrorResponse('Invalid status', 400));
        }

        const result = await LeaveModel.action(
            requestId,
            status,
            req.user.employeeId,
            remarks,
            substitute_employee_id || null
        );

        // result.result_status tells us if advanced to level 2 or fully resolved
        const isAdvanced = result?.result_status === 'Pending' && result?.next_level === 2;
        const message = isAdvanced
            ? 'Level 1 approved — request forwarded to Level 2 approver'
            : `Request ${status.toLowerCase()} successfully`;

        sendResponse(res, 200, message, result);
    } catch (error) { next(error); }
};

// @desc    Cancel a leave request
// @route   DELETE /api/leaves/:id
const deleteRequest = async (req, res, next) => {
    try {
        const result = await LeaveModel.cancel(req.params.id, req.user.employeeId, req.user.role);

        if (result?.affected_rows === 0) {
            return next(new ErrorResponse(result.message || 'Request not found', 404));
        }

        sendResponse(res, 200, 'Leave request cancelled successfully');
    } catch (error) {
        if (error.message?.includes('Not authorized') || error.message?.includes('only cancel')) {
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
