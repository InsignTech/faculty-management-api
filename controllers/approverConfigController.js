const ApproverConfigModel = require('../models/approverConfigModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

/**
 * GET /api/approver-config/:employeeId
 * Returns all 3 configs (LEAVE, REGULARISATION, ONDUTY) for an employee.
 */
const getConfig = async (req, res, next) => {
    try {
        const employeeId = parseInt(req.params.employeeId);
        const configs = await ApproverConfigModel.getAllConfigs(employeeId);
        sendResponse(res, 200, 'Approver configurations fetched', configs);
    } catch (error) {
        next(error);
    }
};

/**
 * GET /api/approver-config/:employeeId/:requestType
 * Returns config for a specific request type.
 */
const getConfigByType = async (req, res, next) => {
    try {
        const { employeeId, requestType } = req.params;
        const config = await ApproverConfigModel.getConfig(parseInt(employeeId), requestType.toUpperCase());
        sendResponse(res, 200, 'Approver configuration fetched', config);
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/approver-config
 * Save/update approver config for employee + request type.
 * Body: { employee_id, request_type, approver_1_id, approver_2_id }
 */
const saveConfig = async (req, res, next) => {
    try {
        const { employee_id, request_type, approver_1_id, approver_2_id } = req.body;

        if (!employee_id || !request_type || !approver_1_id) {
            return next(new ErrorResponse('employee_id, request_type, and approver_1_id are required', 400));
        }

        const validTypes = ['LEAVE', 'REGULARISATION', 'ONDUTY'];
        if (!validTypes.includes(request_type.toUpperCase())) {
            return next(new ErrorResponse('request_type must be LEAVE, REGULARISATION, or ONDUTY', 400));
        }

        const result = await ApproverConfigModel.saveConfig(
            employee_id,
            request_type.toUpperCase(),
            approver_1_id,
            approver_2_id || null
        );
        sendResponse(res, 200, 'Approver configuration saved', result);
    } catch (error) {
        next(error);
    }
};

/**
 * GET /api/approver-config/check-substitute
 * Query: { substitute_id, start_date, end_date }
 * Returns conflicts if substitute has approved/pending leave in that range.
 */
const checkSubstitute = async (req, res, next) => {
    try {
        const { substitute_id, start_date, end_date } = req.query;

        if (!substitute_id || !start_date || !end_date) {
            return next(new ErrorResponse('substitute_id, start_date, and end_date are required', 400));
        }

        const conflicts = await ApproverConfigModel.checkSubstituteAvailability(
            parseInt(substitute_id),
            start_date,
            end_date
        );

        sendResponse(res, 200, 'Substitute availability checked', {
            available: conflicts.length === 0,
            conflicts
        });
    } catch (error) {
        next(error);
    }
};

module.exports = {
    getConfig,
    getConfigByType,
    saveConfig,
    checkSubstitute
};
