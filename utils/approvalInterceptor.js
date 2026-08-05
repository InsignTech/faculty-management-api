const OperationApproverConfigModel = require('../models/operationApproverConfigModel');
const GenericApprovalModel = require('../models/genericApprovalModel');
const pool = require('../config/db');
const ErrorResponse = require('./errorResponse');

/**
 * Intercepts an action and routes it to the approval flow if an approver configuration exists.
 * Otherwise, executes the callback immediately.
 * 
 * @param {string} requestType - 'EMPLOYEE', 'PAYROLL', 'HOLIDAY', 'SHIFT', 'LEAVE'
 * @param {string} actionType - 'CREATE', 'UPDATE', 'DELETE', 'ASSIGN'
 * @param {number|string|null} entityId - Target entity ID
 * @param {object} requestedData - New/proposed data payload
 * @param {object|null} originalData - Existing data payload (before changes)
 * @param {number} requesterId - Employee ID of the person making request
 * @param {function} executeCallback - Async function to run immediately if no config is set
 * @returns {Promise<object>} - Results or message indicating pending approval
 */
async function interceptApproval({
    requestType,
    actionType,
    entityId,
    requestedData,
    originalData = null,
    requesterId,
    executeCallback
}) {
    // Check for duplicate pending requests of the same requestType
    const [pendingRequests] = await pool.execute(
        `SELECT id, requested_data, entity_id, action_type FROM generic_approvals WHERE request_type = ? AND status = 'Pending'`,
        [requestType]
    );

    if (requestType === 'EMPLOYEE' && actionType === 'CREATE') {
        const duplicate = pendingRequests.find(r => {
            if (r.action_type !== 'CREATE') return false;
            try {
                const data = JSON.parse(r.requested_data);
                return (
                    (data.code && requestedData.code && data.code.toString().toLowerCase() === requestedData.code.toString().toLowerCase()) ||
                    (data.email && requestedData.email && data.email.toString().toLowerCase() === requestedData.email.toString().toLowerCase())
                );
            } catch (e) {
                return false;
            }
        });
        if (duplicate) {
            throw new ErrorResponse(`A registration request for employee code "${requestedData.code}" or email "${requestedData.email}" is already pending approval (REQ-${duplicate.id}).`, 409, 'PENDING_APPROVAL_CONFLICT');
        }
    }

    if (entityId && actionType === 'UPDATE') {
        const duplicate = pendingRequests.find(r => 
            r.entity_id && parseInt(r.entity_id) === parseInt(entityId) && r.action_type === 'UPDATE'
        );
        if (duplicate) {
            throw new ErrorResponse(`There is already a pending update request for this entity (REQ-${duplicate.id}). Please wait until it is actioned.`, 409, 'PENDING_APPROVAL_CONFLICT');
        }
    }

    if (entityId && actionType === 'DELETE') {
        const duplicate = pendingRequests.find(r => 
            r.entity_id && parseInt(r.entity_id) === parseInt(entityId) && r.action_type === 'DELETE'
        );
        if (duplicate) {
            throw new ErrorResponse(`There is already a pending deletion request for this entity (REQ-${duplicate.id}).`, 409, 'PENDING_APPROVAL_CONFLICT');
        }
    }

    // 1. Fetch config
    const config = await OperationApproverConfigModel.getConfig(requestType);

    // 2. If no config, bypass and execute immediately
    if (!config || !config.approver_1_id) {
        const result = await executeCallback();
        return { pendingApproval: false, result };
    }

    // Check if requester is the Level 1 Approver
    const isRequesterLevel1 = parseInt(requesterId) === parseInt(config.approver_1_id);

    if (isRequesterLevel1) {
        // If there is no Level 2 approver, or Level 2 is the same as Level 1:
        // No further approvals are needed, execute immediately!
        if (!config.approver_2_id || parseInt(config.approver_2_id) === parseInt(config.approver_1_id)) {
            const result = await executeCallback();
            return { pendingApproval: false, result };
        }

        // If Level 2 exists and is different, auto-promote to Level 2 immediately
        const requestId = await GenericApprovalModel.createRequest({
            request_type: requestType,
            entity_id: entityId,
            action_type: actionType,
            original_data: originalData,
            requested_data: requestedData,
            requester_id: requesterId,
            approver_1_id: config.approver_1_id,
            approver_2_id: config.approver_2_id,
            current_level: 2,
            remarks: 'Level 1 auto-approved (Requester is Level 1 Approver)'
        });

        return {
            pendingApproval: true,
            message: 'Your request has been submitted. Level 1 is auto-approved, pending Level 2 approval.',
            requestId
        };
    }

    // 3. Create the approval request normally for Level 1
    const requestId = await GenericApprovalModel.createRequest({
        request_type: requestType,
        entity_id: entityId,
        action_type: actionType,
        original_data: originalData,
        requested_data: requestedData,
        requester_id: requesterId,
        approver_1_id: config.approver_1_id,
        approver_2_id: config.approver_2_id,
        current_level: 1
    });

    return {
        pendingApproval: true,
        message: 'This operation requires approval. Your request has been submitted to the configured approver(s).',
        requestId
    };
}

module.exports = { interceptApproval };
