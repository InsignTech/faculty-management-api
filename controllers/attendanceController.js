const AttendanceModel = require('../models/attendanceModel');
const EmployeeModel = require('../models/employeeModel');
const LeaveRequestModel = require('../models/leaveRequestModel');
const pool = require('../config/db');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const processAttendanceLogs = async (req, res, next) => {
    try {
        const { date } = req.body;
        if (!date) return next(new ErrorResponse('Please provide a date to process logs for', 400));
        const result = await AttendanceModel.processLogs(date);
        sendResponse(res, 200, `Successfully processed attendance logs for ${date}`, result);
    } catch (error) { next(error); }
};

const getMyAttendance = async (req, res, next) => {
    try {
        const loggedInEmpId = req.user.employeeId;
        const targetEmpId = req.query.employeeId || loggedInEmpId;

        if (!targetEmpId) return next(new ErrorResponse('User is not associated with an employee record', 400, 'MISSING_EMPLOYEE_RECORD'));

        // Permission check
        const userRole = req.user.role?.toLowerCase();
        const isAdmin = ['admin', 'super_admin', 'principal'].includes(userRole);
        
        if (!isAdmin && parseInt(targetEmpId) !== parseInt(loggedInEmpId)) {
            const isSub = await EmployeeModel.isSubordinate(loggedInEmpId, targetEmpId);
            if (!isSub) {
                return next(new ErrorResponse('You are not authorized to view this employee\'s attendance', 403, 'FORBIDDEN'));
            }
        }

        const month = req.query.month || new Date().getMonth() + 1;
        const year = req.query.year || new Date().getFullYear();
        const attendance = await AttendanceModel.getEmployeeAttendance(targetEmpId, month, year);
        sendResponse(res, 200, 'Attendance history fetched successfully', attendance);
    } catch (error) { next(error); }
};

const getMyAttendanceSummary = async (req, res, next) => {
    try {
        const loggedInEmpId = req.user.employeeId;
        const targetEmpId = req.query.employeeId || loggedInEmpId;

        if (!targetEmpId) return next(new ErrorResponse('User is not associated with an employee record', 400, 'MISSING_EMPLOYEE_RECORD'));

        // Permission check
        const userRole = req.user.role?.toLowerCase();
        const isAdmin = ['admin', 'super_admin', 'principal'].includes(userRole);

        if (!isAdmin && parseInt(targetEmpId) !== parseInt(loggedInEmpId)) {
            const isSub = await EmployeeModel.isSubordinate(loggedInEmpId, targetEmpId);
            if (!isSub) {
                return next(new ErrorResponse('You are not authorized to view this employee\'s attendance summary', 403, 'FORBIDDEN'));
            }
        }

        const month = req.query.month || new Date().getMonth() + 1;
        const year = req.query.year || new Date().getFullYear();
        let summary = await AttendanceModel.getAttendanceSummary(targetEmpId, month, year);
        
        // Ensure summary is an object even if no records found
        if (!summary) {
            summary = {
                present_count: 0,
                absent_count: 0,
                late_count: 0,
                early_leaving_count: 0,
                regularized_count: 0,
                onduty_count: 0,
                leave_days: 0,
                total_deductions: 0
            };
        }

        // Fetch Leave Balance
        try {
            const balances = await LeaveRequestModel.getLeaveBalance(targetEmpId);
            summary.leave_balance = balances.reduce((sum, b) => sum + b.available, 0);
        } catch (err) {
            console.error('Failed to fetch leave balance for summary:', err);
            summary.leave_balance = 0;
        }

        // Fetch Month Leaves Taken (Approved & Pending)
        try {
            const [takenRows] = await pool.execute(
                `SELECT COALESCE(SUM(total_days), 0) as taken 
                 FROM leave_requests 
                 WHERE employee_id = ? AND status IN ('Approved', 'Pending')
                 AND MONTH(start_date) = ? AND YEAR(start_date) = ?`,
                [targetEmpId, month, year]
            );
            summary.month_leaves_taken = takenRows[0].taken;
        } catch (err) {
            console.error('Failed to fetch month leaves taken for summary:', err);
            summary.month_leaves_taken = 0;
        }

        sendResponse(res, 200, 'Attendance summary fetched', summary);
    } catch (error) { next(error); }
};

const getIrregularDays = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) return next(new ErrorResponse('User is not associated with an employee record', 400, 'MISSING_EMPLOYEE_RECORD'));

        const month = req.query.month || new Date().getMonth() + 1;
        const year = req.query.year || new Date().getFullYear();
        
        const irregular = await AttendanceModel.getIrregularAttendance(employeeId, month, year);
        sendResponse(res, 200, 'Irregular attendance days fetched', irregular);
    } catch (error) { next(error); }
};

const requestAdjustment = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) return next(new ErrorResponse('User is not associated with an employee record', 400, 'MISSING_EMPLOYEE_RECORD'));
        
        const { 
            type, date, from_date, to_date, 
            requested_in_time, requested_out_time, punch_time, 
            regularization_shift_type, 
            reason, remarks, 
            attachment_path 
        } = req.body;
        
        // Validation: require type
        if (!type) {
            return next(new ErrorResponse('type is required', 400));
        }

        // Basic validation for dates based on type
        if (type === 'Regularization' && !date) {
            return next(new ErrorResponse('date is required for regularization', 400));
        }
        if (type === 'OnDuty' && !date && !from_date) {
            return next(new ErrorResponse('date or from_date is required for On-Duty', 400));
        }

        const result = await AttendanceModel.requestAdjustment({ 
            employee_id: employeeId, 
            type, 
            date, 
            from_date, 
            to_date, 
            requested_in_time: requested_in_time || punch_time, 
            requested_out_time,
            regularization_shift_type,
            reason: reason || remarks, 
            attachment_path 
        });
        
        sendResponse(res, 201, 'Adjustment request submitted successfully', result);
    } catch (error) { next(error); }
};

const getMyAdjustments = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) return next(new ErrorResponse('User is not associated with an employee record', 400, 'MISSING_EMPLOYEE_RECORD'));
        
        const month = req.query.month || null;
        const year = req.query.year || null;
        
        const adjustments = await AttendanceModel.getEmployeeAdjustments(employeeId, month, year);
        sendResponse(res, 200, 'Adjustment history fetched', adjustments);
    } catch (error) { next(error); }
};

const getPendingAdjustments = async (req, res, next) => {
    try {
        const userRole = req.user.role?.toLowerCase();
        const isAdmin = ['admin', 'super_admin', 'principal'].includes(userRole);
        const employeeId = req.user.employeeId;

        if (!employeeId) {
            return next(new ErrorResponse('User is not associated with an employee record', 400));
        }

        let pending;
        if (isAdmin) {
            // Admins see everything
            pending = await AttendanceModel.getPendingAdjustments();
        } else {
            // Managers see subordinates
            pending = await AttendanceModel.getPendingSubordinateAdjustments(employeeId);
        }

        sendResponse(res, 200, 'Pending adjustments fetched', pending);
    } catch (error) { next(error); }
};

const approveAdjustment = async (req, res, next) => {
    try {
        const { id } = req.params;
        const approverId = req.user.employeeId;
        const { remarks } = req.body;

        if (!approverId) return next(new ErrorResponse('User is not associated with an employee record', 400));

        // Get request details to check owner
        const [adj] = await AttendanceModel.getEmployeeAdjustmentsById(id);
        if (!adj) return next(new ErrorResponse('Adjustment request not found', 404));

        // Permission check
        const userRole = req.user.role?.toLowerCase();
        const isAdmin = ['admin', 'super_admin', 'principal'].includes(userRole);
        
        if (!isAdmin) {
            const isSub = await EmployeeModel.isSubordinate(approverId, adj.employee_id);
            if (!isSub) {
                return next(new ErrorResponse('You are not authorized to approve this request', 403));
            }
        }

        const result = await AttendanceModel.approveAdjustment(id, approverId, remarks);
        sendResponse(res, 200, 'Adjustment approved', result);
    } catch (error) { next(error); }
};

const rejectAdjustment = async (req, res, next) => {
    try {
        const { id } = req.params;
        const approverId = req.user.employeeId;
        const { remarks } = req.body;

        if (!approverId) return next(new ErrorResponse('User is not associated with an employee record', 400));
        if (!remarks) return next(new ErrorResponse('Please provide a reason for rejection', 400));

        // Get request details to check owner
        const [adj] = await AttendanceModel.getEmployeeAdjustmentsById(id);
        if (!adj) return next(new ErrorResponse('Adjustment request not found', 404));

        // Permission check
        const userRole = req.user.role?.toLowerCase();
        const isAdmin = ['admin', 'super_admin', 'principal'].includes(userRole);
        
        if (!isAdmin) {
            const isSub = await EmployeeModel.isSubordinate(approverId, adj.employee_id);
            if (!isSub) {
                return next(new ErrorResponse('You are not authorized to reject this request', 403));
            }
        }

        const result = await AttendanceModel.rejectAdjustment(id, approverId, remarks);
        sendResponse(res, 200, 'Adjustment rejected', result);
    } catch (error) { next(error); }
};

const deleteAdjustment = async (req, res, next) => {
    try {
        const { id } = req.params;
        const employeeId = req.user.employeeId;
        const result = await AttendanceModel.deleteAdjustment(id, employeeId);
        
        if (result.affected_rows === 0) {
            return next(new ErrorResponse('Adjustment not found or is already processed', 404));
        }
        
        sendResponse(res, 200, 'Adjustment request deleted successfully', result);
    } catch (error) { next(error); }
};

const uploadMachineLogs = async (req, res, next) => {
    let syncId = null;
    const logs = req.body; // Expecting array of { employee_id, punch_time }

    if (!Array.isArray(logs)) {
        return next(new ErrorResponse('Expected an array of attendance records', 400));
    }

    try {
        // 1. Start synchronization log
        const preview = JSON.stringify(logs.slice(0, 3));
        syncId = await AttendanceModel.startSyncLog(logs.length, preview);

        // 2. Perform bulk insertion (INSERT IGNORE)
        const affectedRows = await AttendanceModel.insertMachineLogs(logs);

        // 3. Complete synchronization log
        await AttendanceModel.endSyncLog(syncId, 'Success');

        sendResponse(res, 201, `Synchronized ${affectedRows} new punch records from ${logs.length} entries.`, {
            total_received: logs.length,
            new_records: affectedRows,
            sync_id: syncId
        });
    } catch (error) {
        // Log failure if we already started a sync record
        if (syncId) {
            await AttendanceModel.endSyncLog(syncId, 'Failed', error.message);
        }
        next(error);
    }
};

module.exports = {
    processAttendanceLogs,
    getMyAttendance,
    getMyAttendanceSummary,
    getIrregularDays,
    requestAdjustment,
    getMyAdjustments,
    getPendingAdjustments,
    approveAdjustment,
    rejectAdjustment,
    deleteAdjustment,
    uploadMachineLogs
};
