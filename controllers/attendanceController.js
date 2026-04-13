const AttendanceModel = require('../models/attendanceModel');
const EmployeeModel = require('../models/employeeModel');
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
        const summary = await AttendanceModel.getAttendanceSummary(targetEmpId, month, year);
        sendResponse(res, 200, 'Attendance summary fetched', summary);
    } catch (error) { next(error); }
};

const requestAdjustment = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) return next(new ErrorResponse('User is not associated with an employee record', 400, 'MISSING_EMPLOYEE_RECORD'));
        const { type, date, punch_time, remarks, attachment_path } = req.body;
        if (!type || !date || !punch_time) return next(new ErrorResponse('type, date and punch_time are required', 400));
        const result = await AttendanceModel.requestAdjustment({ employee_id: employeeId, type, date, punch_time, remarks, attachment_path });
        sendResponse(res, 201, 'Adjustment request submitted successfully', result);
    } catch (error) { next(error); }
};

const getMyAdjustments = async (req, res, next) => {
    try {
        const employeeId = req.user.employeeId;
        if (!employeeId) return next(new ErrorResponse('User is not associated with an employee record', 400, 'MISSING_EMPLOYEE_RECORD'));
        const adjustments = await AttendanceModel.getEmployeeAdjustments(employeeId);
        sendResponse(res, 200, 'Adjustment history fetched', adjustments);
    } catch (error) { next(error); }
};

const getPendingAdjustments = async (req, res, next) => {
    try {
        const pending = await AttendanceModel.getPendingAdjustments();
        sendResponse(res, 200, 'Pending adjustments fetched', pending);
    } catch (error) { next(error); }
};

const approveAdjustment = async (req, res, next) => {
    try {
        const { id } = req.params;
        const approverId = req.user.employeeId;
        const { remarks } = req.body;
        const result = await AttendanceModel.approveAdjustment(id, approverId, remarks);
        sendResponse(res, 200, 'Adjustment approved and deductions recalculated', result);
    } catch (error) { next(error); }
};

const rejectAdjustment = async (req, res, next) => {
    try {
        const { id } = req.params;
        const approverId = req.user.employeeId;
        const { remarks } = req.body;
        const result = await AttendanceModel.rejectAdjustment(id, approverId, remarks);
        sendResponse(res, 200, 'Adjustment rejected', result);
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
    requestAdjustment,
    getMyAdjustments,
    getPendingAdjustments,
    approveAdjustment,
    rejectAdjustment,
    uploadMachineLogs
};
