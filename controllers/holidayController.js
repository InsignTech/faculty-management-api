const { HolidayModel, AttendanceSettingsModel } = require('../models/holidayModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

// === Holidays ===
const getHolidays = async (req, res, next) => {
    try {
        const year = req.query.year || new Date().getFullYear();
        const holidays = await HolidayModel.getAll(year);
        sendResponse(res, 200, 'Holidays fetched', holidays);
    } catch (error) { next(error); }
};

const saveHoliday = async (req, res, next) => {
    try {
        const { holiday_id, holiday_date, description, is_active } = req.body;
        if (!holiday_date) return next(new ErrorResponse('holiday_date is required', 400));
        const result = await HolidayModel.save(holiday_id || 0, holiday_date, description, is_active ?? 1);
        sendResponse(res, 200, 'Holiday saved', result);
    } catch (error) { next(error); }
};

const deleteHoliday = async (req, res, next) => {
    try {
        const { id } = req.params;
        const result = await HolidayModel.delete(id);
        sendResponse(res, 200, 'Holiday deleted', result);
    } catch (error) { next(error); }
};

// === Attendance Settings ===
const getSettings = async (req, res, next) => {
    try {
        const settings = await AttendanceSettingsModel.getAll();
        sendResponse(res, 200, 'Settings fetched', settings);
    } catch (error) { next(error); }
};

const updateSetting = async (req, res, next) => {
    try {
        const { key, value } = req.body;
        if (!key || !value) return next(new ErrorResponse('key and value are required', 400));
        const result = await AttendanceSettingsModel.updateSetting(key, value);
        sendResponse(res, 200, 'Setting updated', result);
    } catch (error) { next(error); }
};

module.exports = { getHolidays, saveHoliday, deleteHoliday, getSettings, updateSetting };
