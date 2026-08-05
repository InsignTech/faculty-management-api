const express = require('express');
const router = express.Router();
const payrollController = require('../controllers/payrollController');
const { protect, authorize } = require('../middleware/auth');

// Protect all routes
router.use(protect);

router.route('/configuration-status')
    .get(payrollController.getEmployeesConfigStatus);

// --- Periods ---
router.route('/periods')
    .get(payrollController.getPeriods)
    .post(payrollController.createPeriod);

router.route('/periods/:id')
    .put(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.updatePeriod)
    .delete(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.deletePeriod);

// --- Deduction Rules ---
router.route('/deduction-rules')
    .get(payrollController.getDeductionRules)
    .post(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.createDeductionRule);

router.route('/deduction-rules/:id')
    .put(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.updateDeductionRule)
    .delete(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.deleteDeductionRule);

// --- Tax Slabs ---
router.route('/tax-slabs')
    .get(payrollController.getTaxSlabs)
    .post(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.createTaxSlab);

router.route('/tax-slabs/:id')
    .put(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.updateTaxSlab)
    .delete(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.deleteTaxSlab);

// --- Employee Configs ---
router.route('/employees/:empId/salary-structure')
    .get(payrollController.getSalaryStructure)
    .post(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.saveSalaryStructure);

router.route('/employees/:empId/deduction-configs')
    .get(payrollController.getDeductionConfigs)
    .post(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.saveDeductionConfig);

router.route('/employees/:empId/tds-config')
    .get(payrollController.getTdsConfig)
    .post(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.saveTdsConfig);

router.route('/employees/:empId/bank-accounts')
    .get(payrollController.getBankAccounts)
    .post(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.saveBankAccount);

router.route('/employees/:empId/loans')
    .get(payrollController.getLoans)
    .post(payrollController.createLoan);

router.route('/loans/:id')
    .put(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.updateLoanStatus);

router.route('/loans/tracker')
    .get(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.getLoanTracker);

// --- Processing Operations ---
router.route('/periods/:id/run')
    .post(payrollController.runPayroll)
    .delete(payrollController.deletePayrollRun);

router.route('/periods/:id/action')
    .post(payrollController.actionPayrollPeriod);

router.route('/periods/:id/disbursements')
    .get(payrollController.getDisbursements);

router.route('/disbursements/:id')
    .put(authorize('super_admin', 'Admin', 'Principal', 'Operations Manager', 'operations manager'), payrollController.updateDisbursement);

router.route('/periods/:id/employees/:empId/lop-details')
    .get(payrollController.getLopDetails);

router.route('/periods/:id/statement')
    .get(payrollController.getStatement);

router.route('/periods/:id/export-excel')
    .get(payrollController.exportExcel);

router.route('/periods/:id/approval-logs')
    .get(payrollController.getApprovalLogs);

// --- Workflow Config ---
router.route('/workflow-config')
    .get(payrollController.getWorkflowConfig)
    .put(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.updateWorkflowConfig);

router.route('/workflow-users')
    .get(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.getWorkflowUsers);

router.route('/workflow-roles')
    .get(authorize('super_admin', 'Admin', 'Operations Manager', 'operations manager'), payrollController.getWorkflowRoles);

module.exports = router;
