const HolidayModel = require('../models/holidayModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const getGeneralHolidays = async (req, res, next) => {
  try {
    const { year } = req.query;
    const holidays = await HolidayModel.getGeneralHolidays(year);
    sendResponse(res, 200, 'General holidays fetched successfully', holidays);
  } catch (error) {
    next(error);
  }
};

const getEmployeeHolidays = async (req, res, next) => {
  try {
    const { search, page, limit, year } = req.query;
    const data = await HolidayModel.getEmployeeHolidays({
      search,
      page: parseInt(page) || 1,
      limit: parseInt(limit) || 10,
      year
    });
    sendResponse(res, 200, 'Employee holidays fetched successfully', data);
  } catch (error) {
    next(error);
  }
};

const saveHoliday = async (req, res, next) => {
  try {
    const { 
      holiday_id, employee_id, employee_ids, holiday_name, holiday_start_date, 
      holiday_end_date, holiday_type, description, is_active 
    } = req.body;

    if (!holiday_name || !holiday_start_date || !holiday_type) {
      return next(new ErrorResponse('Name, start date, and type are required', 400));
    }

    // Handle batch assignment for multiple employees
    if (!holiday_id && Array.isArray(employee_ids) && employee_ids.length > 0) {
      const results = [];
      for (const emp_id of employee_ids) {
        try {
          const result = await HolidayModel.saveHoliday({
            holiday_id,
            employee_id: emp_id,
            holiday_name,
            holiday_start_date,
            holiday_end_date: holiday_end_date || holiday_start_date,
            holiday_type,
            description,
            is_active: is_active !== undefined ? is_active : 1
          });
          results.push({ employee_id: emp_id, success: true, result });
        } catch (error) {
          // Gracefully handle duplicate keys (MySQL error ER_DUP_ENTRY / 1062)
          if (error.code === 'ER_DUP_ENTRY' || error.errno === 1062) {
            results.push({ employee_id: emp_id, success: false, reason: 'Duplicate entry ignored' });
          } else {
            throw error; // Rethrow other database errors
          }
        }
      }
      return sendResponse(res, 200, 'Holidays assigned to selected employees', results);
    }

    const result = await HolidayModel.saveHoliday({
      holiday_id,
      employee_id: employee_id !== undefined ? employee_id : -1,
      holiday_name,
      holiday_start_date,
      holiday_end_date: holiday_end_date || holiday_start_date,
      holiday_type,
      description,
      is_active: is_active !== undefined ? is_active : 1
    });

    const message = holiday_id ? 'Holiday updated successfully' : 'Holiday created successfully';
    sendResponse(res, 200, message, result);
  } catch (error) {
    next(error);
  }
};

const deleteHoliday = async (req, res, next) => {
  try {
    const { id } = req.params;
    const success = await HolidayModel.deleteHoliday(id);
    if (!success) {
      return next(new ErrorResponse('Holiday not found', 404));
    }
    sendResponse(res, 200, 'Holiday deleted successfully');
  } catch (error) {
    next(error);
  }
};

const getUpcomingHolidays = async (req, res, next) => {
  try {
    const employeeId = req.query.employeeId || (req.user && req.user.employeeId);
    if (!employeeId) {
      return next(new ErrorResponse('Employee ID is required', 400));
    }
    const holidays = await HolidayModel.getUpcomingHolidays(employeeId);
    sendResponse(res, 200, 'Upcoming holidays fetched successfully', holidays);
  } catch (error) {
    next(error);
  }
};

const getPersonalHolidays = async (req, res, next) => {
  try {
    const employeeId = req.user && req.user.employeeId;
    const { year } = req.query;
    if (!employeeId) {
      return next(new ErrorResponse('Employee ID is required', 400));
    }
    const holidays = await HolidayModel.getPersonalHolidays(employeeId, year);
    sendResponse(res, 200, 'Personal holidays fetched successfully', holidays);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getGeneralHolidays,
  getEmployeeHolidays,
  saveHoliday,
  deleteHoliday,
  getUpcomingHolidays,
  getPersonalHolidays
};
