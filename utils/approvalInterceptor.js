const OperationApproverConfigModel = require('../models/operationApproverConfigModel');
const GenericApprovalModel = require('../models/genericApprovalModel');
const pool = require('../config/db');
const ErrorResponse = require('./errorResponse');

/**
 * Intercepts an action and routes it to the approval flow if an approver configuration exists.
 * Otherwise, executes the callback immediately.
 * 
 * Super Admin users bypass all approvals and changes execute directly.
 * 
 * @param {string} requestType - 'EMPLOYEE', 'PAYROLL', 'HOLIDAY', 'SHIFT', 'LEAVE_POLICY', 'APPROVER_CONFIG'
 * @param {string} actionType - 'CREATE', 'UPDATE', 'DELETE', 'ASSIGN', etc.
 * @param {number|string|null} entityId - Target entity ID
 * @param {object} requestedData - New/proposed data payload
 * @param {object|null} originalData - Existing data payload (before changes)
 * @param {number|null} requesterId - Employee ID of the person making request
 * @param {string|null} requesterRole - User's role name
 * @param {object|null} user - Decoded JWT user object from req.user
 * @param {function} executeCallback - Async function to run immediately if no config is set or if bypassed
 * @returns {Promise<object>} - Results or message indicating pending approval
 */
async function interceptApproval({
    requestType,
    actionType,
    entityId,
    requestedData,
    originalData = null,
    requesterId,
    requesterRole = null,
    user = null,
    executeCallback
}) {
    // 0. Super Admin check: Super admin does NOT need any approvals - changes go directly
    const roleName = (requesterRole || user?.role || '').toLowerCase().trim();
    let isSuperAdmin = ['super_admin', 'superadmin', 'super admin'].includes(roleName) || 
                       user?.roleId === 1 || 
                       user?.role_id === 1;

    if (!isSuperAdmin && (requesterId || user?.id)) {
        try {
            const checkId = user?.id || requesterId;
            const [userRows] = await pool.query(
                `SELECT r.role FROM user_accounts ua 
                 LEFT JOIN employee e ON ua.employee_id = e.employee_id 
                 LEFT JOIN app_role r ON r.role_id = COALESCE(e.role_id, ua.role_id) 
                 WHERE ua.user_accounts_id = ? OR ua.employee_id = ?`,
                [checkId, checkId]
            );
            if (userRows.length > 0 && ['super_admin', 'superadmin', 'super admin'].includes((userRows[0].role || '').toLowerCase().trim())) {
                isSuperAdmin = true;
            }
        } catch (err) {
            console.error('Error checking superadmin status in interceptApproval:', err.message);
        }
    }

    if (isSuperAdmin) {
        const result = await executeCallback();
        return { pendingApproval: false, result };
    }

    // Check for duplicate pending requests of the same requestType
    const [pendingRequests] = await pool.execute(
        `SELECT id, requested_data, entity_id, action_type FROM generic_approvals WHERE request_type = ? AND status = 'Pending'`,
        [requestType]
    );

    if (requestType === 'SHIFT' && actionType === 'ASSIGN') {
        let targetEmpIds = [];
        if (requestedData.employee_id) {
            targetEmpIds.push(parseInt(requestedData.employee_id));
        } else if (requestedData.role_id) {
            const roleIds = Array.isArray(requestedData.role_id) ? requestedData.role_id : [requestedData.role_id];
            const activeRoleIds = roleIds.filter(id => id && id !== 'all');
            if (activeRoleIds.length > 0) {
                const [rows] = await pool.query('SELECT employee_id FROM employee WHERE role_id IN (?) AND active = 1', [activeRoleIds]);
                targetEmpIds = rows.map(r => parseInt(r.employee_id));
            }
        }

        const newStart = new Date(requestedData.from_date);
        const newEnd = requestedData.to_date ? new Date(requestedData.to_date) : new Date('9999-12-31');

        const shiftPending = pendingRequests.filter(r => r.action_type === 'ASSIGN');
        for (const r of shiftPending) {
            try {
                const existingData = JSON.parse(r.requested_data);
                if (!existingData) continue;

                let existingEmpIds = [];
                if (existingData.employee_id) {
                    existingEmpIds.push(parseInt(existingData.employee_id));
                } else if (existingData.role_id) {
                    const roleIds = Array.isArray(existingData.role_id) ? existingData.role_id : [existingData.role_id];
                    const activeRoleIds = roleIds.filter(id => id && id !== 'all');
                    if (activeRoleIds.length > 0) {
                        const [rows] = await pool.query('SELECT employee_id FROM employee WHERE role_id IN (?) AND active = 1', [activeRoleIds]);
                        existingEmpIds = rows.map(r => parseInt(r.employee_id));
                    }
                }

                const intersection = targetEmpIds.filter(id => existingEmpIds.includes(id));
                if (intersection.length > 0) {
                    const existStart = new Date(existingData.from_date);
                    const existEnd = existingData.to_date ? new Date(existingData.to_date) : new Date('9999-12-31');

                    const overlap = newStart <= existEnd && existStart <= newEnd;
                    if (overlap) {
                        throw new ErrorResponse(
                            `Cannot assign shift. There is already a pending shift assignment request (REQ-${r.id}) that overlaps with this date range for one or more of the selected employees.`,
                            409,
                            'PENDING_APPROVAL_CONFLICT'
                        );
                    }
                }
            } catch (e) {
                if (e.errorCode === 'PENDING_APPROVAL_CONFLICT') throw e;
            }
        }
    }

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
        const duplicate = pendingRequests.find(r => {
            const matchesEntity = r.entity_id && parseInt(r.entity_id) === parseInt(entityId) && r.action_type === 'UPDATE';
            if (!matchesEntity) return false;

            if (requestType === 'APPROVER_CONFIG') {
                try {
                    const existingData = JSON.parse(r.requested_data);
                    return existingData && requestedData && existingData.request_type === requestedData.request_type;
                } catch (e) {
                    return false;
                }
            }
            return true;
        });

        if (duplicate) {
            const subMessage = requestType === 'APPROVER_CONFIG' ? ` for ${requestedData.request_type}` : '';
            throw new ErrorResponse(`There is already a pending update request for this entity${subMessage} (REQ-${duplicate.id}). Please wait until it is actioned.`, 409, 'PENDING_APPROVAL_CONFLICT');
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
    const configRequestType = requestType === 'LEAVE_POLICY' ? 'LEAVE' : requestType;
    const config = await OperationApproverConfigModel.getConfig(configRequestType);

    // 2. If no config, bypass and execute immediately
    if (!config || !config.approver_1_id) {
        const result = await executeCallback();
        return { pendingApproval: false, result };
    }

    // If the requester is the final approver (either Level 2, or Level 1 when there's no Level 2), bypass and execute immediately
    const finalApproverId = config.approver_2_id || config.approver_1_id;
    const isRequesterFinalApprover = requesterId && finalApproverId && parseInt(requesterId) === parseInt(finalApproverId);

    if (isRequesterFinalApprover) {
        const result = await executeCallback();
        return { pendingApproval: false, result };
    }

    // Check if requester is the Level 1 Approver
    const isRequesterLevel1 = requesterId && config.approver_1_id && parseInt(requesterId) === parseInt(config.approver_1_id);

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
