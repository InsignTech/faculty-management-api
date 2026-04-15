const HolidayModel = require('../models/holidayModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const getHolidays = async (req, res, next) => {
    try {
        const { year } = req.query;
        const holidays = await HolidayModel.getAll(year || null);
        sendResponse(res, 200, 'Holidays fetched successfully', holidays);
    } catch (error) { next(error); }
};

const saveHoliday = async (req, res, next) => {
    try {
        const { holiday_id, holiday_date, description, is_active } = req.body;
        
        if (!holiday_date || !description) {
            return next(new ErrorResponse('Date and description are required', 400));
        }

        const result = await HolidayModel.save({ holiday_id, holiday_date, description, is_active });
        const message = holiday_id ? 'Holiday updated successfully' : 'Holiday created successfully';
        
        sendResponse(res, 200, message, result);
    } catch (error) { next(error); }
};

const deleteHoliday = async (req, res, next) => {
    try {
        const { id } = req.params;
        const result = await HolidayModel.delete(id);
        
        if (result.affected_rows === 0) {
            return next(new ErrorResponse('Holiday not found', 404));
        }
        
        sendResponse(res, 200, 'Holiday deleted successfully');
    } catch (error) { next(error); }
};

const getSettings = async (req, res, next) => {
    try {
        const settings = await HolidayModel.getSettings();
        sendResponse(res, 200, 'Settings fetched successfully', settings);
    } catch (error) { next(error); }
};

const updateSetting = async (req, res, next) => {
    try {
        const { key, value } = req.body;
        if (!key || value === undefined) {
            return next(new ErrorResponse('Key and value are required', 400));
        }
        await HolidayModel.updateSetting(key, value);
        sendResponse(res, 200, 'Setting updated successfully');
    } catch (error) { next(error); }
};

module.exports = {
    getHolidays,
    saveHoliday,
    deleteHoliday,
    getSettings,
    updateSetting
};
