const ReportModel = require('../models/reportModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');
let XLSX;
try {
    XLSX = require('xlsx');
} catch (e) {
    XLSX = null;
}

const getAttendanceReport = async (req, res, next) => {
    try {
        const { startDate, endDate, employeeId, departmentId, search, page = 1, limit = 50 } = req.query;

        if (!startDate || !endDate) {
            return next(new ErrorResponse('Start and End dates are required', 400));
        }

        const userRole = (req.user.role || '').toLowerCase();
        const isAdmin = ['admin', 'principal', 'super_admin'].includes(userRole);
        const reportData = await ReportModel.getAttendanceReport(req.user.employeeId, isAdmin, {
            startDate, endDate, employeeId, departmentId, search
        });

        // Manual pagination since the report is generated as a matrix
        const startIndex = (page - 1) * limit;
        const paginatedData = reportData.slice(startIndex, startIndex + parseInt(limit));

        sendResponse(res, 200, 'Report fetched successfully', {
            data: paginatedData,
            totalRows: reportData.length,
            currentPage: parseInt(page),
            totalPages: Math.ceil(reportData.length / limit)
        });
    } catch (error) { next(error); }
};

const exportAttendanceReport = async (req, res, next) => {
    try {
        if (!XLSX) {
            return next(new ErrorResponse('Excel export library (xlsx) is not installed on the server. Please run "npm install xlsx".', 500));
        }

        const { startDate, endDate, employeeId, departmentId, search } = req.query;

        if (!startDate || !endDate) {
            return next(new ErrorResponse('Start and End dates are required', 400));
        }

        const userRole = (req.user.role || '').toLowerCase();
        const isAdmin = ['admin', 'principal', 'super_admin'].includes(userRole);
        const reportData = await ReportModel.getAttendanceReport(req.user.employeeId, isAdmin, {
            startDate, endDate, employeeId, departmentId, search
        });

        // Format data for Excel
        const excelData = reportData.map(row => ({
            'Date': row.date,
            'Emp Code': row.employee_code,
            'Name': row.employee_name,
            'Department': row.department,
            'Status': row.status,
            'Remark': row.remark,
            'Punch In': row.punch_in || '-',
            'Punch Out': row.punch_out || '-',
            'Worked (Mins)': row.worked_mins || 0,
            'Late (Mins)': row.late_minutes || 0,
            'Early Leaving (Mins)': row.early_minutes || 0,
            'Overtime (Mins)': row.overtime_minutes || 0,
            'Deduction (Days)': row.deduction_days || 0
        }));

        const wb = XLSX.utils.book_new();
        const ws = XLSX.utils.json_to_sheet(excelData);
        XLSX.utils.book_append_sheet(wb, ws, 'Attendance Report');

        const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });

        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', `attachment; filename=Attendance_Report_${startDate}_to_${endDate}.xlsx`);
        res.send(buf);

    } catch (error) { next(error); }
};

module.exports = {
    getAttendanceReport,
    exportAttendanceReport
};
