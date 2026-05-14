const LeavePolicyModel = require('../models/leavePolicyModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const LEAVE_TYPES = [
  'Sick Leave',
  'Casual Leave',
  'Annual Leave',
  'Maternity Leave',
  'Paternity Leave',
  'Loss of Pay',
  'Compensatory Off',
  'Marriage Leave',
  'Bereavement Leave',
  'Emergency Leave',
  'On Duty',
  'Restricted Holiday',
  'Half-Day Leave',
  'Medical Leave',
  'Study Leave',
  'Sabbatical Leave',
  'Adoption Leave',
  'Child Care Leave',
  'Business Travel Leave',
  'Work From Home',
  'Mental Health Leave'
];

const validatePolicyValue = (policyValue) => {
  if (!Array.isArray(policyValue)) return false;
  return policyValue.every(item => LEAVE_TYPES.includes(item.leaveType));
};

// --- System Level ---

const getSystemPolicies = async (req, res, next) => {
  try {
    const policies = await LeavePolicyModel.getAllSystemPolicies();
    const parsedPolicies = policies.map(p => ({
      ...p,
      policy_value: p.policy_value ? JSON.parse(p.policy_value) : []
    }));
    sendResponse(res, 200, 'System policies fetched successfully', parsedPolicies);
  } catch (error) {
    next(error);
  }
};

const createSystemPolicy = async (req, res, next) => {
  try {
    const { policy_name, start_date, end_date, policy_value } = req.body;
    if (!policy_name || !start_date) {
      return next(new ErrorResponse('Policy name and start date are required', 400));
    }
    if (policy_value && !validatePolicyValue(policy_value)) {
      return next(new ErrorResponse('Invalid leave types provided', 400));
    }

    const created_by = req.user ? req.user.username : 'admin';
    const result = await LeavePolicyModel.createSystemPolicy({
      policy_name,
      start_date,
      end_date,
      policy_value: policy_value || [],
      created_by
    });
    sendResponse(res, 201, 'System policy created successfully', result);
  } catch (error) {
    next(error);
  }
};

const updateSystemPolicy = async (req, res, next) => {
  try {
    const { policy_name, start_date, end_date, policy_value } = req.body;
    if (policy_value && !validatePolicyValue(policy_value)) {
      return next(new ErrorResponse('Invalid leave types provided', 400));
    }

    const result = await LeavePolicyModel.updateSystemPolicy(req.params.id, {
      policy_name,
      start_date,
      end_date,
      policy_value
    });
    sendResponse(res, 200, 'System policy updated successfully', result);
  } catch (error) {
    next(error);
  }
};

const setActiveSystemPolicy = async (req, res, next) => {
  try {
    await LeavePolicyModel.setActiveSystemPolicy(req.params.id);
    sendResponse(res, 200, 'Policy set as active throughout the system');
  } catch (error) {
    next(error);
  }
};

const deleteSystemPolicy = async (req, res, next) => {
  try {
    await LeavePolicyModel.deleteSystemPolicy(req.params.id);
    sendResponse(res, 200, 'System policy deleted successfully');
  } catch (error) {
    next(error);
  }
};

// --- Role Level ---

const getRolePolicy = async (req, res, next) => {
  try {
    const policy = await LeavePolicyModel.getRolePolicy(req.params.id);
    sendResponse(res, 200, 'Role policy fetched successfully', policy || null);
  } catch (error) {
    next(error);
  }
};

const saveRolePolicy = async (req, res, next) => {
  try {
    const { leave_policy_id, role_id, policy_value } = req.body;
    if (policy_value && !validatePolicyValue(policy_value)) {
      return next(new ErrorResponse('Invalid leave types provided', 400));
    }

    const created_by = req.user ? req.user.username : 'admin';
    await LeavePolicyModel.saveRolePolicy({
      leave_policy_id,
      role_id,
      policy_value,
      created_by
    });
    sendResponse(res, 201, 'Role policy saved successfully');
  } catch (error) {
    next(error);
  }
};

// --- Employee Level ---

const getEmployeePolicy = async (req, res, next) => {
  try {
    const policy = await LeavePolicyModel.getEmployeePolicy(req.params.id);
    sendResponse(res, 200, 'Employee policy fetched successfully', policy || null);
  } catch (error) {
    next(error);
  }
};

const saveEmployeePolicy = async (req, res, next) => {
  try {
    const { leave_policy_id, employee_id, policy_value } = req.body;
    if (policy_value && !validatePolicyValue(policy_value)) {
      return next(new ErrorResponse('Invalid leave types provided', 400));
    }

    const created_by = req.user ? req.user.username : 'admin';
    await LeavePolicyModel.saveEmployeePolicy({
      leave_policy_id,
      employee_id,
      policy_value,
      created_by
    });
    sendResponse(res, 201, 'Employee policy saved successfully');
  } catch (error) {
    next(error);
  }
};

const getEffectivePolicy = async (req, res, next) => {
  try {
    const policy = await LeavePolicyModel.getEffectivePolicy(req.params.id);
    sendResponse(res, 200, 'Effective policy fetched successfully', policy);
  } catch (error) {
    next(error);
  }
};

const getPolicyHistory = async (req, res, next) => {
  try {
    const history = await LeavePolicyModel.getPolicyHistory(req.params.id || null);
    sendResponse(res, 200, 'Policy history fetched successfully', history);
  } catch (error) {
    next(error);
  }
};

const calculateAccrual = async (req, res, next) => {
  try {
    const dryRun = req.query.dryRun === 'true';
    const targetDate = req.query.date || null;
    const result = await LeavePolicyModel.calculateAccrual(dryRun, targetDate);
    
    if (dryRun) {
      return sendResponse(res, 200, 'Dry run completed successfully', result);
    }
    
    sendResponse(res, 200, 'Leave accrual calculation completed successfully');
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getSystemPolicies,
  createSystemPolicy,
  updateSystemPolicy,
  setActiveSystemPolicy,
  deleteSystemPolicy,
  getRolePolicy,
  saveRolePolicy,
  getEmployeePolicy,
  saveEmployeePolicy,
  getEffectivePolicy,
  calculateAccrual,
  getPolicyHistory
};
