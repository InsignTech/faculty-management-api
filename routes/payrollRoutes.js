const express = require('express');
const router = express.Router();
const payrollController = require('../controllers/payrollController');
const { protect, authorize } = require('../middleware/auth');

// Protect all routes
router.use(protect);

// --- Periods ---
router.route('/periods')
    .get(payrollController.getPeriods)
    .post(authorize('super_admin', 'Admin', 'payroll_admin', 'payrolladmin'), payrollController.createPeriod);

router.route('/periods/:id')
    .put(authorize('super_admin', 'Admin', 'Principal'), payrollController.updatePeriod);

// --- Deduction Rules ---
router.route('/deduction-rules')
    .get(payrollController.getDeductionRules)
    .post(authorize('super_admin', 'Admin'), payrollController.createDeductionRule);

router.route('/deduction-rules/:id')
    .put(authorize('super_admin', 'Admin'), payrollController.updateDeductionRule)
    .delete(authorize('super_admin', 'Admin'), payrollController.deleteDeductionRule);

// --- Tax Slabs ---
router.route('/tax-slabs')
    .get(payrollController.getTaxSlabs)
    .post(authorize('super_admin', 'Admin'), payrollController.createTaxSlab);

router.route('/tax-slabs/:id')
    .put(authorize('super_admin', 'Admin'), payrollController.updateTaxSlab)
    .delete(authorize('super_admin', 'Admin'), payrollController.deleteTaxSlab);

// --- Employee Configs ---
router.route('/employees/:empId/salary-structure')
    .get(payrollController.getSalaryStructure)
    .post(authorize('super_admin', 'Admin', 'Principal'), payrollController.saveSalaryStructure);

router.route('/employees/:empId/deduction-configs')
    .get(payrollController.getDeductionConfigs)
    .post(authorize('super_admin', 'Admin', 'Principal'), payrollController.saveDeductionConfig);

router.route('/employees/:empId/tds-config')
    .get(payrollController.getTdsConfig)
    .post(authorize('super_admin', 'Admin', 'Principal'), payrollController.saveTdsConfig);

router.route('/employees/:empId/bank-accounts')
    .get(payrollController.getBankAccounts)
    .post(authorize('super_admin', 'Admin', 'Principal'), payrollController.saveBankAccount);

router.route('/employees/:empId/loans')
    .get(payrollController.getLoans)
    .post(payrollController.createLoan);

router.route('/loans/:id')
    .put(authorize('super_admin', 'Admin', 'Principal'), payrollController.updateLoanStatus);

router.route('/loans/tracker')
    .get(authorize('super_admin', 'Admin', 'Principal'), payrollController.getLoanTracker);

// --- Processing Operations ---
router.route('/periods/:id/run')
    .post(authorize('super_admin', 'Admin', 'payroll_admin', 'payrolladmin'), payrollController.runPayroll)
    .delete(authorize('super_admin', 'Admin', 'payroll_admin', 'payrolladmin'), payrollController.deletePayrollRun);

router.route('/periods/:id/action')
    .post(authorize('super_admin', 'Admin', 'Principal'), payrollController.actionPayrollPeriod);

router.route('/periods/:id/disbursements')
    .get(payrollController.getDisbursements);

router.route('/disbursements/:id')
    .put(authorize('super_admin', 'Admin', 'Principal'), payrollController.updateDisbursement);

router.route('/periods/:id/employees/:empId/lop-details')
    .get(payrollController.getLopDetails);

router.route('/periods/:id/statement')
    .get(payrollController.getStatement);

router.route('/periods/:id/approval-logs')
    .get(payrollController.getApprovalLogs);

module.exports = router;
