const ExceptionalModel = require('../models/exceptionalModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

// @desc    Get all global exceptional days
// @route   GET /api/exceptional
// @access  Private
const getExceptionalDays = async (req, res, next) => {
    try {
        const year = req.query.year || null;
        const data = await ExceptionalModel.getAll(year);
        sendResponse(res, 200, 'Exceptional days fetched successfully', data);
    } catch (error) { next(error); }
};

// @desc    Add/Update global exceptional day
// @route   POST /api/exceptional
// @access  Private (Admin only)
const saveExceptionalDay = async (req, res, next) => {
    try {
        const { holiday_date, description, is_active, exceptional_id } = req.body;
        if (!holiday_date || !description) {
            return next(new ErrorResponse('Please provide date and description', 400));
        }

        const result = await ExceptionalModel.save({
            exceptional_id,
            holiday_date,
            description,
            is_active
        });

        sendResponse(res, 201, 'Exceptional day saved successfully', result);
    } catch (error) { next(error); }
};

// @desc    Delete global exceptional day
// @route   DELETE /api/exceptional/:id
// @access  Private (Admin only)
const deleteExceptionalDay = async (req, res, next) => {
    try {
        const result = await ExceptionalModel.delete(req.params.id);
        if (result.affected_rows === 0) {
            return next(new ErrorResponse('Record not found', 404));
        }

        sendResponse(res, 200, 'Record deleted successfully');
    } catch (error) { next(error); }
};

module.exports = {
    getExceptionalDays,
    saveExceptionalDay,
    deleteExceptionalDay
};
