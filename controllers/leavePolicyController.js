const LeavePolicyModel = require('../models/leavePolicyModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

// --- System Level ---

const getSystemPolicies = async (req, res, next) => {
  try {
    const policies = await LeavePolicyModel.getAllSystemPolicies();
    // Parse JSON values
    const parsedPolicies = policies.map(p => ({
      ...p,
      policy_value: p.policy_value ? JSON.parse(p.policy_value) : [],
      weekly_off: p.weekly_off ? JSON.parse(p.weekly_off) : ["Sunday"]
    }));
    sendResponse(res, 200, 'System policies fetched successfully', parsedPolicies);
  } catch (error) {
    next(error);
  }
};

const createSystemPolicy = async (req, res, next) => {
  try {
    const { policy_name, policy_year, policy_value, weekly_off } = req.body;
    if (!policy_name || !policy_year) {
      return next(new ErrorResponse('Policy name and year are required', 400));
    }
    const created_by = req.user ? req.user.username : 'admin';
    const result = await LeavePolicyModel.createSystemPolicy({
      policy_name,
      policy_year,
      policy_value: policy_value || [],
      weekly_off: weekly_off || ["Sunday"],
      created_by
    });
    sendResponse(res, 201, 'System policy created successfully', result);
  } catch (error) {
    next(error);
  }
};

const updateSystemPolicy = async (req, res, next) => {
  try {
    const { policy_name, policy_year, policy_value, weekly_off } = req.body;
    const result = await LeavePolicyModel.updateSystemPolicy(req.params.id, {
      policy_name,
      policy_year,
      policy_value,
      weekly_off
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

// --- Designation Level ---

const getDesignationPolicy = async (req, res, next) => {
  try {
    const policy = await LeavePolicyModel.getDesignationPolicy(req.params.id);
    sendResponse(res, 200, 'Designation policy fetched successfully', policy || null);
  } catch (error) {
    next(error);
  }
};

const saveDesignationPolicy = async (req, res, next) => {
  try {
    const { leave_policy_id, designation_id, policy_value } = req.body;
    const created_by = req.user ? req.user.username : 'admin';
    await LeavePolicyModel.saveDesignationPolicy({
      leave_policy_id,
      designation_id,
      policy_value,
      created_by
    });
    sendResponse(res, 201, 'Designation policy saved successfully');
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
    const { leave_policy_id, role_id, policy_value, weekly_off } = req.body;
    const created_by = req.user ? req.user.username : 'admin';
    await LeavePolicyModel.saveRolePolicy({
      leave_policy_id,
      role_id,
      policy_value,
      weekly_off,
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

module.exports = {
  getSystemPolicies,
  createSystemPolicy,
  updateSystemPolicy,
  setActiveSystemPolicy,
  deleteSystemPolicy,
  getDesignationPolicy,
  saveDesignationPolicy,
  getRolePolicy,
  saveRolePolicy,
  getEmployeePolicy,
  saveEmployeePolicy
};
