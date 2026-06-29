const PayrollModel = require('../models/payrollModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');
const excelHelper = require('../utils/excelHelper');

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
const isAuthorizedForLevel1 = async (req) => {
    const userRole = req.user.role ? req.user.role.toLowerCase() : '';
    if (['super_admin', 'admin'].includes(userRole)) {
        return true;
    }
    const configs = await PayrollModel.getWorkflowConfig();
    const activeConfig = configs.find(c => c.level_name === 'submitted');
    if (activeConfig) {
        const userId = req.user.id;
        const matchesUser = activeConfig.assigned_to_user_id !== null && activeConfig.assigned_to_user_id === userId;
        const matchesRole = activeConfig.assigned_to_role !== null && activeConfig.assigned_to_role.toLowerCase() === userRole;
        return matchesUser || matchesRole;
    }
    return false;
};

const runPayroll = async (req, res, next) => {
    try {
        if (!(await isAuthorizedForLevel1(req))) {
            return next(new ErrorResponse("You are not authorized to run payroll calculations. Only the assigned Level 1 (Submit) user or role can perform this action.", 403));
        }
        const preparedBy = req.user?.employeeId || 999; // Fallback to super_admin id if needed
        const result = await PayrollModel.runPayroll(req.params.id, preparedBy);
        sendResponse(res, 200, 'Payroll processed successfully', result);
    } catch (e) { next(e); }
};

const deletePayrollRun = async (req, res, next) => {
    try {
        if (!(await isAuthorizedForLevel1(req))) {
            return next(new ErrorResponse("You are not authorized to delete payroll runs. Only the assigned Level 1 (Submit) user or role can perform this action.", 403));
        }
        const affected = await PayrollModel.deletePayrollRun(req.params.id);
        if (affected === 0) return next(new ErrorResponse('Payroll period not found', 404));
        sendResponse(res, 200, 'Payroll run deleted successfully');
    } catch (e) { next(e); }
};

const actionPayrollPeriod = async (req, res, next) => {
    try {
        const { action, remarks } = req.body;
        if (!action) {
            return next(new ErrorResponse('Please provide action', 400));
        }

        // Dynamic Workflow Authorization Check
        // Actions: 'submitted', 'verified', 'approved', 'paid', 'rejected'
        if (action !== 'rejected') {
            const configs = await PayrollModel.getWorkflowConfig();
            const activeConfig = configs.find(c => c.level_name === action);

            if (activeConfig) {
                const userId = req.user.id;
                const userRole = req.user.role ? req.user.role.toLowerCase() : '';
                
                const matchesUser = activeConfig.assigned_to_user_id !== null && activeConfig.assigned_to_user_id === userId;
                const matchesRole = activeConfig.assigned_to_role !== null && activeConfig.assigned_to_role.toLowerCase() === userRole;
                const isSuperAdmin = userRole === 'super_admin';

                if (!matchesUser && !matchesRole && !isSuperAdmin) {
                    return next(new ErrorResponse(`You are not authorized to perform the '${action}' action. Only the assigned user or role (${activeConfig.assigned_to_role || 'Specific User'}) can perform this step.`, 403));
                }
            }
        }

        const actionBy = req.user?.employeeId || 999;
        const result = await PayrollModel.actionPayrollPeriod(req.params.id, action, actionBy, remarks);
        sendResponse(res, 200, `Payroll cycle status advanced to ${action}`, result);
    } catch (e) { next(e); }
};

const getWorkflowConfig = async (req, res, next) => {
    try {
        const data = await PayrollModel.getWorkflowConfig();
        sendResponse(res, 200, 'Workflow config fetched successfully', data);
    } catch (e) { next(e); }
};

const updateWorkflowConfig = async (req, res, next) => {
    try {
        const { level_id, assigned_to_user_id, assigned_to_role } = req.body;
        if (!level_id) {
            return next(new ErrorResponse('Please provide level_id', 400));
        }
        await PayrollModel.updateWorkflowConfig(level_id, assigned_to_user_id, assigned_to_role);
        sendResponse(res, 200, 'Workflow level updated successfully');
    } catch (e) { next(e); }
};

const getWorkflowUsers = async (req, res, next) => {
    try {
        const data = await PayrollModel.getWorkflowUsers();
        sendResponse(res, 200, 'Workflow users fetched successfully', data);
    } catch (e) { next(e); }
};

const getWorkflowRoles = async (req, res, next) => {
    try {
        const data = await PayrollModel.getWorkflowRoles();
        sendResponse(res, 200, 'Workflow roles fetched successfully', data);
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

const getLopDetails = async (req, res, next) => {
    try {
        const data = await PayrollModel.getLopDetails(req.params.id, req.params.empId);
        sendResponse(res, 200, 'LOP details fetched successfully', data);
    } catch (e) { next(e); }
};

const updateDisbursement = async (req, res, next) => {
    try {
        const actionBy = req.user?.employeeId || 999;
        const affected = await PayrollModel.updateDisbursement(req.params.id, req.body, actionBy);
        if (affected === 0) return next(new ErrorResponse('Disbursement not found', 404));
        sendResponse(res, 200, 'Disbursement updated successfully');
    } catch (e) { next(e); }
};

const exportExcel = async (req, res, next) => {
    try {
        const workbook = await excelHelper.generateExcelStatement(req.params.id);
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', `attachment; filename=payroll_statement_${req.params.id}.xlsx`);
        await workbook.xlsx.write(res);
        res.end();
    } catch (e) { next(e); }
};

module.exports = {
    exportExcel,
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
    deletePayrollRun,
    actionPayrollPeriod,
    getDisbursements,
    getStatement,
    getLoanTracker,
    getApprovalLogs,
    getLopDetails,
    updateDisbursement,
    getWorkflowConfig,
    updateWorkflowConfig,
    getWorkflowUsers,
    getWorkflowRoles
};
