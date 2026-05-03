const LeaveRequestModel = require('../models/leaveRequestModel');
const { sendResponse } = require('../utils/responseHelper');
const pool = require('../config/db');

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

const checkHolidays = async (req, res, next) => {
  try {
    const { start_date, end_date, employee_id } = req.query;
    if (!start_date || !end_date) {
      return sendResponse(res, 400, 'start_date and end_date are required', []);
    }
    const empId = employee_id || req.user?.employeeId || -1;
    const [rows] = await pool.execute(
      `SELECT holiday_name, holiday_type,
              DATE_FORMAT(holiday_start_date, '%Y-%m-%d') AS holiday_start_date,
              DATE_FORMAT(holiday_end_date, '%Y-%m-%d') AS holiday_end_date
       FROM holiday_master
       WHERE is_active = 1
         AND (employee_id = -1 OR employee_id = ?)
         AND holiday_type != 'WeekEnd'
         AND holiday_start_date <= ? AND holiday_end_date >= ?`,
      [empId, end_date, start_date]
    );
    sendResponse(res, 200, 'Holidays fetched', rows);
  } catch (error) {
    next(error);
  }
};

const cancelLeaveRequest = async (req, res, next) => {
  try {
    const { id } = req.params;
    const employeeId = req.user?.employeeId;

    // Only allow cancellation of own pending requests
    const [rows] = await pool.execute(
      'SELECT status, employee_id FROM leave_requests WHERE leave_request_id = ?',
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Leave request not found' });
    }

    const request = rows[0];

    if (request.employee_id !== employeeId) {
      return res.status(403).json({ success: false, message: 'You can only cancel your own requests' });
    }

    if (request.status !== 'Pending') {
      return res.status(400).json({ success: false, message: `Cannot cancel a request that is already ${request.status}` });
    }

    await pool.execute('DELETE FROM leave_requests WHERE leave_request_id = ?', [id]);
    sendResponse(res, 200, 'Leave request cancelled successfully');
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getLeaveRequests,
  createLeaveRequest,
  getTeamRequests,
  updateRequestStatus,
  getEmployeeBalance,
  checkHolidays,
  cancelLeaveRequest
};
