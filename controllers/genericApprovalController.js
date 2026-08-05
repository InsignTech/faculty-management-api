const GenericApprovalModel = require('../models/genericApprovalModel');
const EmployeeModel = require('../models/employeeModel');
const PayrollModel = require('../models/payrollModel');
const HolidayModel = require('../models/holidayModel');
const ShiftModel = require('../models/shiftModel');
const OperationApproverConfigModel = require('../models/operationApproverConfigModel');
const ApproverConfigModel = require('../models/approverConfigModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const getPendingApprovals = async (req, res, next) => {
    try {
        const loggedInEmpId = req.user.employeeId || req.user.employee_id;
        if (!loggedInEmpId) {
            return next(new ErrorResponse('Employee ID not found in token', 400));
        }
        const pending = await GenericApprovalModel.getPendingForApprover(loggedInEmpId);
        sendResponse(res, 200, 'Pending operations approvals fetched', pending);
    } catch (error) {
        next(error);
    }
};

const getApprovalsHistory = async (req, res, next) => {
    try {
        const loggedInEmpId = req.user.employeeId || req.user.employee_id;
        if (!loggedInEmpId) {
            return next(new ErrorResponse('Employee ID not found in token', 400));
        }
        const history = await GenericApprovalModel.getApprovalsHistory(loggedInEmpId);
        sendResponse(res, 200, 'Operations approvals history fetched', history);
    } catch (error) {
        next(error);
    }
};

const actionApproval = async (req, res, next) => {
    try {
        const { id } = req.params;
        const { status, remarks } = req.body; // 'Approved' or 'Rejected'
        const loggedInEmpId = req.user.employeeId || req.user.employee_id;

        if (!status || !['Approved', 'Rejected'].includes(status)) {
            return next(new ErrorResponse('status must be Approved or Rejected', 400));
        }

        const approvalRequest = await GenericApprovalModel.getById(id);
        if (!approvalRequest) {
            return next(new ErrorResponse('Approval request not found', 404));
        }

        if (approvalRequest.status !== 'Pending') {
            return next(new ErrorResponse('This request is already actioned', 400));
        }

        // Verify authorization
        const isApprover1 = approvalRequest.current_level === 1 && approvalRequest.approver_1_id === loggedInEmpId;
        const isApprover2 = approvalRequest.current_level === 2 && approvalRequest.approver_2_id === loggedInEmpId;
        const isAdmin = ['admin', 'super_admin', 'principal', 'operations manager', 'operations_manager'].includes(req.user.role?.toLowerCase());

        if (!isApprover1 && !isApprover2 && !isAdmin) {
            return next(new ErrorResponse('You are not authorized to action this request', 403));
        }

        if (status === 'Rejected') {
            await GenericApprovalModel.actionRequest(id, 'Rejected', remarks || 'Rejected by approver', loggedInEmpId);
            return sendResponse(res, 200, 'Request has been rejected');
        }

        // If Approved, handle levels
        if (approvalRequest.current_level === 1 && approvalRequest.approver_2_id && approvalRequest.approver_2_id !== approvalRequest.approver_1_id) {
            // If Level 2 approver is the requester themselves, their approval is implied. Apply changes immediately!
            if (approvalRequest.approver_2_id === approvalRequest.requester_id) {
                // Implied Level 2 approval. Fall through to apply changes.
            } else {
                // Promote to Level 2
                await GenericApprovalModel.updateLevel(id, 2);
                return sendResponse(res, 200, 'Request approved and promoted to Level 2');
            }
        }

        // Final Approval - Execute actual logic
        const requestType = approvalRequest.request_type;
        const actionType = approvalRequest.action_type;
        const entityId = approvalRequest.entity_id;
        const requestedData = approvalRequest.requested_data ? JSON.parse(approvalRequest.requested_data) : null;

        console.log(`Executing approved change for type: ${requestType}, action: ${actionType}`);

        if (requestType === 'EMPLOYEE') {
            if (actionType === 'CREATE') {
                await EmployeeModel.create(requestedData);
            } else if (actionType === 'UPDATE') {
                await EmployeeModel.update(entityId, requestedData);
            } else if (actionType === 'DELETE') {
                await EmployeeModel.delete(entityId);
            }
        } else if (requestType === 'PAYROLL') {
            const { subtype, payload } = requestedData;
            if (subtype === 'SALARY_STRUCTURE') {
                await PayrollModel.saveSalaryStructure(entityId, payload);
            } else if (subtype === 'DEDUCTION_CONFIG') {
                await PayrollModel.saveDeductionConfig(entityId, payload);
            } else if (subtype === 'TDS_CONFIG') {
                await PayrollModel.saveTdsConfig(entityId, payload);
            } else if (subtype === 'BANK_ACCOUNT') {
                await PayrollModel.saveBankAccount(entityId, payload);
            }
        } else if (requestType === 'HOLIDAY') {
            if (actionType === 'CREATE' || actionType === 'UPDATE') {
                await HolidayModel.saveHoliday(requestedData);
            } else if (actionType === 'DELETE') {
                await HolidayModel.deleteHoliday(entityId);
            }
        } else if (requestType === 'SHIFT') {
            if (actionType === 'UPDATE') {
                await ShiftModel.updateGlobalShift(entityId, requestedData);
            } else if (actionType === 'ASSIGN') {
                await ShiftModel.assignEmployeeShifts(
                    requestedData.employee_id,
                    requestedData.from_date,
                    requestedData.to_date,
                    requestedData.shifts,
                    requestedData.modified_by
                );
            }
        } else if (requestType === 'APPROVER_CONFIG') {
            if (actionType === 'UPDATE') {
                const { employee_id, request_type, approver_1_id, approver_2_id } = requestedData;
                await ApproverConfigModel.saveConfig(
                    employee_id,
                    request_type,
                    approver_1_id,
                    approver_2_id
                );
            }
        }

        // Mark request as Approved
        await GenericApprovalModel.actionRequest(id, 'Approved', remarks || 'Approved', loggedInEmpId);
        sendResponse(res, 200, 'Request approved and changes applied successfully');
    } catch (error) {
        next(error);
    }
};

const checkAccess = async (req, res, next) => {
    try {
        const loggedInEmpId = req.user.employeeId || req.user.employee_id;
        const role = req.user.role?.toLowerCase();

        // Superadmin, principal, and operations manager always have access
        if (['super_admin', 'principal', 'operations manager', 'operations_manager'].includes(role)) {
            return sendResponse(res, 200, 'Access allowed', { hasAccess: true });
        }

        if (!loggedInEmpId) {
            return sendResponse(res, 200, 'Access denied', { hasAccess: false });
        }

        const isApprover = await OperationApproverConfigModel.checkApproverAccess(loggedInEmpId);
        sendResponse(res, 200, 'Access checked', { hasAccess: isApprover });
    } catch (error) {
        next(error);
    }
};

const getMyRequests = async (req, res, next) => {
    try {
        const loggedInEmpId = req.user.employeeId || req.user.employee_id;
        if (!loggedInEmpId) {
            return next(new ErrorResponse('Employee ID not found in token', 400));
        }

        const query = `
            SELECT ga.*,
                   a1.employee_name AS approver_1_name,
                   a2.employee_name AS approver_2_name,
                   act.employee_name AS actioned_by_name
            FROM generic_approvals ga
            LEFT JOIN employee a1 ON ga.approver_1_id = a1.employee_id
            LEFT JOIN employee a2 ON ga.approver_2_id = a2.employee_id
            LEFT JOIN employee act ON ga.actioned_by_id = act.employee_id
            WHERE ga.requester_id = ?
            ORDER BY ga.requested_on DESC
        `;
        const [rows] = await pool.execute(query, [loggedInEmpId]);
        sendResponse(res, 200, 'My submitted requests fetched', rows);
    } catch (error) {
        next(error);
    }
};

module.exports = {
    getPendingApprovals,
    getApprovalsHistory,
    actionApproval,
    checkAccess,
    getMyRequests
};
