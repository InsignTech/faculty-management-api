const PayrollModel = require('../models/payrollModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

// --- Periods ---
const getPeriods = async (req, res, next) => {
    try {
        const data = await PayrollModel.getPeriods();
        sendResponse(res, 200, 'Periods fetched successfully', data);
    } catch (e) { next(e); }
};

const createPeriod = async (req, res, next) => {
    try {
        const { month, year, start_date, end_date } = req.body;
        if (!month || !year || !start_date || !end_date) {
            return next(new ErrorResponse('Please provide month, year, start_date, and end_date', 400));
        }
        const insertId = await PayrollModel.createPeriod(req.body);
        sendResponse(res, 201, 'Period created successfully', { period_id: insertId });
    } catch (e) { next(e); }
};

const updatePeriod = async (req, res, next) => {
    try {
        const { status } = req.body;
        if (!status) {
            return next(new ErrorResponse('Please provide status', 400));
        }
        const affected = await PayrollModel.updatePeriod(req.params.id, status);
        if (affected === 0) return next(new ErrorResponse('Period not found', 404));
        sendResponse(res, 200, 'Period updated successfully');
    } catch (e) { next(e); }
};

// --- Deduction Rules ---
const getDeductionRules = async (req, res, next) => {
    try {
        const data = await PayrollModel.getDeductionRules();
        sendResponse(res, 200, 'Deduction rules fetched successfully', data);
    } catch (e) { next(e); }
};

const createDeductionRule = async (req, res, next) => {
    try {
        const { deduction_code, deduction_name, calc_type } = req.body;
        if (!deduction_code || !deduction_name || !calc_type) {
            return next(new ErrorResponse('Please provide deduction_code, deduction_name, and calc_type', 400));
        }
        const insertId = await PayrollModel.createDeductionRule(req.body);
        sendResponse(res, 201, 'Deduction rule created successfully', { rule_id: insertId });
    } catch (e) { next(e); }
};

const updateDeductionRule = async (req, res, next) => {
    try {
        const affected = await PayrollModel.updateDeductionRule(req.params.id, req.body);
        if (affected === 0) return next(new ErrorResponse('Rule not found', 404));
        sendResponse(res, 200, 'Deduction rule updated successfully');
    } catch (e) { next(e); }
};

const deleteDeductionRule = async (req, res, next) => {
    try {
        const affected = await PayrollModel.deleteDeductionRule(req.params.id);
        if (affected === 0) return next(new ErrorResponse('Rule not found', 404));
        sendResponse(res, 200, 'Deduction rule deleted successfully');
    } catch (e) { next(e); }
};

// --- Tax Slabs ---
const getTaxSlabs = async (req, res, next) => {
    try {
        const data = await PayrollModel.getTaxSlabs();
        sendResponse(res, 200, 'Tax slabs fetched successfully', data);
    } catch (e) { next(e); }
};

const createTaxSlab = async (req, res, next) => {
    try {
        const { min_salary, monthly_tax, effective_from } = req.body;
        if (min_salary === undefined || monthly_tax === undefined || !effective_from) {
            return next(new ErrorResponse('Please provide min_salary, monthly_tax, and effective_from', 400));
        }
        const insertId = await PayrollModel.createTaxSlab(req.body);
        sendResponse(res, 201, 'Tax slab created successfully', { slab_id: insertId });
    } catch (e) { next(e); }
};

const updateTaxSlab = async (req, res, next) => {
    try {
        const affected = await PayrollModel.updateTaxSlab(req.params.id, req.body);
        if (affected === 0) return next(new ErrorResponse('Tax slab not found', 404));
        sendResponse(res, 200, 'Tax slab updated successfully');
    } catch (e) { next(e); }
};

const deleteTaxSlab = async (req, res, next) => {
    try {
        const affected = await PayrollModel.deleteTaxSlab(req.params.id);
        if (affected === 0) return next(new ErrorResponse('Tax slab not found', 404));
        sendResponse(res, 200, 'Tax slab deleted successfully');
    } catch (e) { next(e); }
};

// --- Employee Configurations ---
const getSalaryStructure = async (req, res, next) => {
    try {
        const data = await PayrollModel.getSalaryStructure(req.params.empId);
        sendResponse(res, 200, 'Salary structures fetched successfully', data);
    } catch (e) { next(e); }
};

const saveSalaryStructure = async (req, res, next) => {
    try {
        const { basic_pay, effective_from } = req.body;
        if (basic_pay === undefined || !effective_from) {
            return next(new ErrorResponse('Please provide basic_pay and effective_from', 400));
        }
        const createdBy = req.user?.username || 'admin';
        const insertId = await PayrollModel.saveSalaryStructure(req.params.empId, { ...req.body, created_by: createdBy });
        sendResponse(res, 201, 'Salary structure updated successfully', { structure_id: insertId });
    } catch (e) { next(e); }
};

const getDeductionConfigs = async (req, res, next) => {
    try {
        const data = await PayrollModel.getDeductionConfigs(req.params.empId);
        sendResponse(res, 200, 'Deduction configs fetched successfully', data);
    } catch (e) { next(e); }
};

const saveDeductionConfig = async (req, res, next) => {
    try {
        const { rule_id } = req.body;
        if (!rule_id) {
            return next(new ErrorResponse('Please provide rule_id', 400));
        }
        await PayrollModel.saveDeductionConfig(req.params.empId, req.body);
        sendResponse(res, 200, 'Deduction config saved successfully');
    } catch (e) { next(e); }
};

const getTdsConfig = async (req, res, next) => {
    try {
        const data = await PayrollModel.getTdsConfig(req.params.empId);
        sendResponse(res, 200, 'TDS config fetched successfully', data);
    } catch (e) { next(e); }
};

const saveTdsConfig = async (req, res, next) => {
    try {
        await PayrollModel.saveTdsConfig(req.params.empId, req.body);
        sendResponse(res, 200, 'TDS config saved successfully');
    } catch (e) { next(e); }
};

const getBankAccounts = async (req, res, next) => {
    try {
        const data = await PayrollModel.getBankAccounts(req.params.empId);
        sendResponse(res, 200, 'Bank accounts fetched successfully', data);
    } catch (e) { next(e); }
};

const saveBankAccount = async (req, res, next) => {
    try {
        const { bank_name, branch_name, account_number, ifsc_code } = req.body;
        if (!bank_name || !branch_name || !account_number || !ifsc_code) {
            return next(new ErrorResponse('Please provide bank_name, branch_name, account_number, and ifsc_code', 400));
        }
        await PayrollModel.saveBankAccount(req.params.empId, req.body);
        sendResponse(res, 200, 'Bank account saved successfully');
    } catch (e) { next(e); }
};

const getLoans = async (req, res, next) => {
    try {
        const data = await PayrollModel.getLoans(req.params.empId);
        sendResponse(res, 200, 'Employee loans fetched successfully', data);
    } catch (e) { next(e); }
};

const createLoan = async (req, res, next) => {
    try {
        const { loan_type, loan_amount, monthly_deduction, deduction_start_month, deduction_start_year } = req.body;
        if (!loan_type || !loan_amount || !monthly_deduction || !deduction_start_month || !deduction_start_year) {
            return next(new ErrorResponse('Please provide all required loan fields', 400));
        }
        const insertId = await PayrollModel.createLoan(req.params.empId, req.body);
        sendResponse(res, 201, 'Loan application created successfully', { loan_id: insertId });
    } catch (e) { next(e); }
};

const updateLoanStatus = async (req, res, next) => {
    try {
        const { status } = req.body;
        if (!status) {
            return next(new ErrorResponse('Please provide status', 400));
        }
        const approvedBy = req.user?.employeeId || null;
        const affected = await PayrollModel.updateLoanStatus(req.params.id, { ...req.body, approved_by: approvedBy });
        if (affected === 0) return next(new ErrorResponse('Loan not found', 404));
        sendResponse(res, 200, 'Loan status updated successfully');
    } catch (e) { next(e); }
};

// --- Processing Operations ---
const runPayroll = async (req, res, next) => {
    try {
        const preparedBy = req.user?.employeeId || 999; // Fallback to super_admin id if needed
        const result = await PayrollModel.runPayroll(req.params.id, preparedBy);
        sendResponse(res, 200, 'Payroll processed successfully', result);
    } catch (e) { next(e); }
};

const actionPayrollPeriod = async (req, res, next) => {
    try {
        const { action, remarks } = req.body;
        if (!action) {
            return next(new ErrorResponse('Please provide action', 400));
        }
        const actionBy = req.user?.employeeId || 999;
        const result = await PayrollModel.actionPayrollPeriod(req.params.id, action, actionBy, remarks);
        sendResponse(res, 200, `Payroll cycle status advanced to ${action}`, result);
    } catch (e) { next(e); }
};

const getDisbursements = async (req, res, next) => {
    try {
        const data = await PayrollModel.getDisbursements(req.params.id);
        sendResponse(res, 200, 'Salary disbursements fetched successfully', data);
    } catch (e) { next(e); }
};

const getStatement = async (req, res, next) => {
    try {
        const data = await PayrollModel.getStatement(req.params.id);
        sendResponse(res, 200, 'Salary statement fetched successfully', data);
    } catch (e) { next(e); }
};

const getLoanTracker = async (req, res, next) => {
    try {
        const data = await PayrollModel.getLoanTracker();
        sendResponse(res, 200, 'Loans fetched successfully', data);
    } catch (e) { next(e); }
};

const getApprovalLogs = async (req, res, next) => {
    try {
        const data = await PayrollModel.getApprovalLogs(req.params.id);
        sendResponse(res, 200, 'Approval logs fetched successfully', data);
    } catch (e) { next(e); }
};

module.exports = {
    getPeriods,
    createPeriod,
    updatePeriod,
    getDeductionRules,
    createDeductionRule,
    updateDeductionRule,
    deleteDeductionRule,
    getTaxSlabs,
    createTaxSlab,
    updateTaxSlab,
    deleteTaxSlab,
    getSalaryStructure,
    saveSalaryStructure,
    getDeductionConfigs,
    saveDeductionConfig,
    getTdsConfig,
    saveTdsConfig,
    getBankAccounts,
    saveBankAccount,
    getLoans,
    createLoan,
    updateLoanStatus,
    runPayroll,
    actionPayrollPeriod,
    getDisbursements,
    getStatement,
    getLoanTracker,
    getApprovalLogs
};
