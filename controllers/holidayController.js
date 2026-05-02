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
      holiday_id, employee_id, holiday_name, holiday_start_date, 
      holiday_end_date, holiday_type, description, is_active 
    } = req.body;

    if (!holiday_name || !holiday_start_date || !holiday_type) {
      return next(new ErrorResponse('Name, start date, and type are required', 400));
    }

    const result = await HolidayModel.saveHoliday({
      holiday_id,
      employee_id: employee_id || -1,
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

module.exports = {
  getGeneralHolidays,
  getEmployeeHolidays,
  saveHoliday,
  deleteHoliday
};
