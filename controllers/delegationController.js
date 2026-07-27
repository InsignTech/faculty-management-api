const DelegationModel = require('../models/delegationModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const createDelegation = async (req, res, next) => {
  try {
    const { delegate_employee_id, target_employee_id } = req.body;
    
    if (!delegate_employee_id || !target_employee_id) {
      return next(new ErrorResponse('Both delegate_employee_id and target_employee_id are required.', 400, 'VALIDATION_ERROR'));
    }

    const createdBy = req.user.username || 'system';
    const result = await DelegationModel.create(delegate_employee_id, target_employee_id, createdBy);
    
    sendResponse(res, 201, 'Delegation mapping created successfully.', result);
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return next(new ErrorResponse('This delegation mapping already exists.', 400, 'DUPLICATE_ENTRY'));
    }
    next(error);
  }
};

const deleteDelegation = async (req, res, next) => {
  try {
    const { id } = req.params;
    await DelegationModel.delete(id);
    sendResponse(res, 200, 'Delegation mapping deleted successfully.');
  } catch (error) {
    next(error);
  }
};

const getDelegations = async (req, res, next) => {
  try {
    const delegations = await DelegationModel.getAll();
    sendResponse(res, 200, 'Delegation mappings fetched successfully.', delegations);
  } catch (error) {
    next(error);
  }
};

const getMyDelegatedTargets = async (req, res, next) => {
  try {
    // Current logged in employee
    const delegateId = req.user.employeeId;
    if (!delegateId) {
      return next(new ErrorResponse('Employee profile not found for logged in user.', 404, 'NOT_FOUND'));
    }
    const targets = await DelegationModel.getDelegatedTargetsForEmployee(delegateId);
    sendResponse(res, 200, 'Your delegated targets fetched successfully.', targets);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createDelegation,
  deleteDelegation,
  getDelegations,
  getMyDelegatedTargets
};
