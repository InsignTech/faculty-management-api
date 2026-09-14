const ApproverConfigModel = require('../models/approverConfigModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');
const { interceptApproval } = require('../utils/approvalInterceptor');

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

        const requesterId = req.user.employeeId || req.user.employee_id;
        const execute = async () => {
            return await ApproverConfigModel.saveConfig(
                employee_id,
                request_type.toUpperCase(),
                approver_1_id,
                approver_2_id || null
            );
        };

        const interceptResult = await interceptApproval({
            requestType: 'APPROVER_CONFIG',
            actionType: 'UPDATE',
            entityId: employee_id,
            requestedData: {
                employee_id: parseInt(employee_id),
                request_type: request_type.toUpperCase(),
                approver_1_id: parseInt(approver_1_id),
                approver_2_id: approver_2_id ? parseInt(approver_2_id) : null
            },
            originalData: null,
            requesterId,
            requesterRole: req.user?.role,
            user: req.user,
            executeCallback: execute
        });

        if (interceptResult.pendingApproval) {
            return sendResponse(res, 202, interceptResult.message, { pendingApproval: true });
        }

        sendResponse(res, 200, 'Approver configuration saved', interceptResult.result);
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

/**
 * GET /api/approver-config/check-my-status
 * Checks if the logged-in user is an approver of anybody or has admin privileges.
 */
const checkApproverStatus = async (req, res, next) => {
    try {
        const pool = require('../config/db');
        const userRole = req.user.role ? req.user.role.toLowerCase() : '';
        const isAdmin = ['super_admin', 'superadmin'].includes(userRole);
        
        if (isAdmin) {
            return sendResponse(res, 200, 'Approver status checked', { isApprover: true, isAdmin: true });
        }

        const employeeId = req.user.employeeId || req.user.employee_id;
        const userId = req.user.id || req.user.user_accounts_id;

        if (!employeeId && !userId) {
            return sendResponse(res, 200, 'Approver status checked', { isApprover: false, isAdmin: false });
        }

        let isApprover = false;

        if (employeeId) {
            // 1. Check reporting_manager_id in employee table
            const [mgrRows] = await pool.execute(
                'SELECT 1 FROM employee WHERE reporting_manager_id = ? LIMIT 1',
                [employeeId]
            );
            if (mgrRows.length > 0) isApprover = true;

            // 2. Check employee_approver_configs table
            if (!isApprover) {
                const [apprRows] = await pool.execute(
                    'SELECT 1 FROM employee_approver_configs WHERE approver_1_id = ? OR approver_2_id = ? LIMIT 1',
                    [employeeId, employeeId]
                );
                if (apprRows.length > 0) isApprover = true;
            }

            // 3. Check active delegations
            if (!isApprover) {
                const [delRows] = await pool.execute(
                    'SELECT 1 FROM delegations WHERE delegatee_id = ? AND status = "active" AND (end_date IS NULL OR end_date >= CURDATE()) LIMIT 1',
                    [employeeId]
                );
                if (delRows.length > 0) isApprover = true;
            }

            // 4. Check operation_approver_config
            if (!isApprover) {
                const [opsRows] = await pool.execute(
                    'SELECT 1 FROM operation_approver_config WHERE approver_id = ? OR substitute_approver_id = ? LIMIT 1',
                    [employeeId, employeeId]
                );
                if (opsRows.length > 0) isApprover = true;
            }

            // 5. Check if user is listed as approver_1 or approver_2 on any existing leave request
            if (!isApprover) {
                const [pendingLeave] = await pool.execute(
                    'SELECT 1 FROM leave_requests WHERE (approver_1_id = ? OR approver_2_id = ?) LIMIT 1',
                    [employeeId, employeeId]
                );
                if (pendingLeave.length > 0) isApprover = true;
            }

            // 6. Check if user is listed as approver_1 or approver_2 on any existing regularization request
            if (!isApprover) {
                const [pendingAdj] = await pool.execute(
                    'SELECT 1 FROM attendance_regularization WHERE (approver_1_id = ? OR approver_2_id = ?) LIMIT 1',
                    [employeeId, employeeId]
                );
                if (pendingAdj.length > 0) isApprover = true;
            }
        }

        if (!isApprover && userId) {
            // 7. Check workflow_config
            const [wfRows] = await pool.execute(
                'SELECT 1 FROM workflow_config WHERE assigned_to_user_id = ? LIMIT 1',
                [userId]
            );
            if (wfRows.length > 0) isApprover = true;
        }

        sendResponse(res, 200, 'Approver status checked', { isApprover, isAdmin: false });
    } catch (error) {
        next(error);
    }
};

module.exports = {
    getConfig,
    getConfigByType,
    saveConfig,
    checkSubstitute,
    checkApproverStatus
};
