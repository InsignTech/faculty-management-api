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
    const userRole = req.user?.role;

    // Fetch the request and the requester's manager info
    const [rows] = await pool.execute(
      'SELECT status, employee_id, start_date, end_date FROM leave_requests WHERE leave_request_id = ?',
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Leave request not found' });
    }

    const request = rows[0];

    // Authorization logic
    const isAdmin = ['super_admin', 'admin', 'Admin', 'Principal', 'principal', 'HOD', 'Manager'].includes(userRole);
    
    // Check if the current user is the reporting manager of the person who requested the leave
    const [managerCheck] = await pool.execute(
      'SELECT 1 FROM employee WHERE employee_id = ? AND reporting_manager_id = ?',
      [request.employee_id, employeeId]
    );
    const isManager = managerCheck.length > 0;

    // Check if it's their own request
    const isOwner = request.employee_id === employeeId;

    if (!isOwner && !isAdmin && !isManager) {
      return res.status(403).json({ success: false, message: 'You are not authorized to cancel this request' });
    }

    // Status logic:
    // Owners can only cancel PENDING requests.
    // Managers/Admins can cancel PENDING or APPROVED requests.
    if (isOwner && !isAdmin && !isManager && request.status !== 'Pending') {
      return res.status(400).json({ success: false, message: 'You can only cancel your own pending requests. For approved leaves, please contact your manager.' });
    }

    if (request.status === 'Rejected' || request.status === 'Cancelled') {
      return res.status(400).json({ success: false, message: `Cannot cancel a request that is already ${request.status}` });
    }

    const LeaveModel = require('../models/leaveModel');
    const result = await LeaveModel.cancel(id, employeeId);
    
    sendResponse(res, 200, 'Leave request cancelled successfully', result);
  } catch (error) {
    next(error);
  }
};

const isPreviousMonth = (dateStr) => {
    if (!dateStr) return false;
    const targetDate = new Date(dateStr);
    const currentDate = new Date();
    
    const targetYear = targetDate.getFullYear();
    const targetMonth = targetDate.getMonth();
    
    const currentYear = currentDate.getFullYear();
    const currentMonth = currentDate.getMonth();
    
    if (targetYear < currentYear) return true;
    if (targetYear === currentYear && targetMonth < currentMonth) return true;
    return false;
};

const superAdminApplyLeave = async (req, res, next) => {
  try {
    const { employee_id, start_date, end_date, confirmPreviousMonth, confirmConflicts } = req.body;
    if (!employee_id || !start_date || !end_date) {
      return res.status(400).json({ success: false, message: 'employee_id, start_date, and end_date are required' });
    }

    if ((isPreviousMonth(start_date) || isPreviousMonth(end_date)) && !confirmPreviousMonth) {
      return res.status(200).json({
        success: false,
        warning: 'previous_month_warning',
        message: 'Warning: One or more dates belong to a previous month. Salary calculation has already been processed for this period. Please confirm to proceed.'
      });
    }

    // Check conflicts if confirmConflicts is not true
    if (!confirmConflicts) {
      // 1. Get attendance daily logs
      const [attendanceRows] = await pool.execute(
        `SELECT date, status, worked_mins, regularization_shift_type, onduty_shift_type, is_leave, leave_shift_type 
         FROM attendance_daily 
         WHERE employee_id = ? AND date BETWEEN ? AND ?`,
        [employee_id, start_date, end_date]
      );
      
      // 2. Get holidays
      const [holidayRows] = await pool.execute(
        `SELECT holiday_name, holiday_start_date, holiday_end_date 
         FROM holiday_master 
         WHERE is_active = 1 
           AND (employee_id = -1 OR employee_id = ?)
           AND (holiday_start_date <= ? AND holiday_end_date >= ?)`,
        [employee_id, end_date, start_date]
      );
      
      const conflicts = [];
      const [sYear, sMonth, sDay] = start_date.split('-').map(Number);
      const [eYear, eMonth, eDay] = end_date.split('-').map(Number);
      
      const start = new Date(sYear, sMonth - 1, sDay);
      const end = new Date(eYear, eMonth - 1, eDay);
      let curr = new Date(start);
      
      while (curr <= end) {
        const year = curr.getFullYear();
        const month = String(curr.getMonth() + 1).padStart(2, '0');
        const day = String(curr.getDate()).padStart(2, '0');
        const dateStr = `${year}-${month}-${day}`;
        
        // Check Sunday
        if (curr.getDay() === 0) {
          conflicts.push(`${dateStr} is a Sunday`);
        }
        
        // Check holiday
        const isHoliday = holidayRows.some(h => {
          const hStart = new Date(h.holiday_start_date);
          const hEnd = new Date(h.holiday_end_date);
          // Set to midnight local to compare timezone-safely
          const checkDate = new Date(year, curr.getMonth(), curr.getDate());
          const compStart = new Date(hStart.getFullYear(), hStart.getMonth(), hStart.getDate());
          const compEnd = new Date(hEnd.getFullYear(), hEnd.getMonth(), hEnd.getDate());
          return checkDate >= compStart && checkDate <= compEnd;
        });
        if (isHoliday) {
          const h = holidayRows.find(h => {
            const hStart = new Date(h.holiday_start_date);
            const hEnd = new Date(h.holiday_end_date);
            const checkDate = new Date(year, curr.getMonth(), curr.getDate());
            const compStart = new Date(hStart.getFullYear(), hStart.getMonth(), hStart.getDate());
            const compEnd = new Date(hEnd.getFullYear(), hEnd.getMonth(), hEnd.getDate());
            return checkDate >= compStart && checkDate <= compEnd;
          });
          conflicts.push(`${dateStr} is a Holiday (${h.holiday_name})`);
        }
        
        // Check attendance daily
        const att = attendanceRows.find(a => {
          let aDate;
          if (a.date instanceof Date) {
            const y = a.date.getFullYear();
            const m = String(a.date.getMonth() + 1).padStart(2, '0');
            const d = String(a.date.getDate()).padStart(2, '0');
            aDate = `${y}-${m}-${d}`;
          } else {
            aDate = String(a.date).split('T')[0];
          }
          return aDate === dateStr;
        });
        if (att) {
          if (att.status === 'Present' || att.worked_mins > 0) {
            conflicts.push(`${dateStr} has existing attendance (Status: Present, Worked: ${att.worked_mins} mins)`);
          } else if (att.regularization_shift_type) {
            conflicts.push(`${dateStr} has an approved regularization (${att.regularization_shift_type})`);
          } else if (att.onduty_shift_type) {
            conflicts.push(`${dateStr} has an approved on-duty (${att.onduty_shift_type})`);
          } else if (att.is_leave) {
            conflicts.push(`${dateStr} already has an approved leave (${att.leave_shift_type || 'FullDay'})`);
          }
        }
        
        curr.setDate(curr.getDate() + 1);
      }
      
      if (conflicts.length > 0) {
        return res.status(200).json({
          success: false,
          warning: 'conflict_warning',
          message: `Warning: The requested leave period overlaps with weekends, holidays, or existing attendance logs:\n\n${conflicts.map(c => `• ${c}`).join('\n')}\n\nProceeding will overwrite attendance status. Do you wish to proceed?`
        });
      }
    }

    const superAdminEmployeeId = req.user?.employeeId || req.user?.id || 1;
    const result = await LeaveRequestModel.superAdminCreateLeave(req.body, superAdminEmployeeId);
    sendResponse(res, 201, 'Leave applied and approved successfully', result);
  } catch (error) {
    next(error);
  }
};

const getApprovedSubstitutesList = async (req, res, next) => {
  try {
    const { date, page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    const filters = {};
    if (date) {
      filters.date = date;
    }

    const { rows: leaves, total } = await LeaveRequestModel.getApprovedWithSubstitutes(filters, parseInt(limit), parseInt(offset));

    sendResponse(res, 200, 'Approved substitute leaves fetched successfully', {
      leaves,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / limit)
      }
    });
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
  cancelLeaveRequest,
  superAdminApplyLeave,
  getApprovedSubstitutesList
};

