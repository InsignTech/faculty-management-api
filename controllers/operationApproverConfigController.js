const OperationApproverConfigModel = require('../models/operationApproverConfigModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const getConfigs = async (req, res, next) => {
    try {
        const configs = await OperationApproverConfigModel.getAllConfigs();
        sendResponse(res, 200, 'Operation approver configurations fetched', configs);
    } catch (error) {
        next(error);
    }
};

const getConfigByType = async (req, res, next) => {
    try {
        const { type } = req.params;
        const config = await OperationApproverConfigModel.getConfig(type.toUpperCase());
        sendResponse(res, 200, `Operation config for ${type} fetched`, config);
    } catch (error) {
        next(error);
    }
};

const saveConfig = async (req, res, next) => {
    try {
        const { request_type, approver_1_id, approver_2_id } = req.body;

        if (!request_type) {
            return next(new ErrorResponse('request_type is required', 400));
        }

        const validTypes = ['EMPLOYEE', 'PAYROLL', 'LEAVE', 'HOLIDAY', 'SHIFT', 'APPROVER_CONFIG'];
        if (!validTypes.includes(request_type.toUpperCase())) {
            return next(new ErrorResponse('request_type must be EMPLOYEE, PAYROLL, LEAVE, HOLIDAY, SHIFT, or APPROVER_CONFIG', 400));
        }

        // If no Level 1 approver is selected/saved, delete config entirely so no approval is needed
        if (!approver_1_id) {
            await OperationApproverConfigModel.deleteConfig(request_type.toUpperCase());
            return sendResponse(res, 200, 'Operation approver configuration cleared successfully');
        }

        await OperationApproverConfigModel.saveConfig(
            request_type.toUpperCase(),
            approver_1_id,
            approver_2_id || null
        );

        sendResponse(res, 200, 'Operation approver configuration saved successfully');
    } catch (error) {
        next(error);
    }
};

module.exports = {
    getConfigs,
    getConfigByType,
    saveConfig
};
