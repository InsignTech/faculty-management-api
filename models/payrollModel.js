const pool = require('../config/db');

class PayrollModel {
    // --- Periods ---
    static async getPeriods() {
        const [rows] = await pool.execute('SELECT * FROM payroll_period ORDER BY year DESC, month DESC');
        return rows;
    }

    static async createPeriod(data) {
        const { organization_id, month, year, start_date, end_date } = data;
        const [result] = await pool.execute(
            `INSERT INTO payroll_period (organization_id, month, year, start_date, end_date, status)
             VALUES (?, ?, ?, ?, ?, 'draft')`,
            [organization_id || 1, month, year, start_date, end_date]
        );
        return result.insertId;
    }

    static async updatePeriod(id, status) {
        const [result] = await pool.execute(
            'UPDATE payroll_period SET status = ? WHERE period_id = ?',
            [status, id]
        );
        return result.affectedRows;
    }

    // --- Deduction Rules ---
    static async getDeductionRules() {
        const [rows] = await pool.execute('SELECT * FROM deduction_rule_master ORDER BY display_order ASC');
        return rows;
    }

    static async createDeductionRule(data) {
        const { organization_id, deduction_code, deduction_name, calc_type, rate, calc_basis, eligibility_ceiling, wage_ceiling, fixed_amount, is_statutory, is_active, display_order, notes } = data;
        const [result] = await pool.execute(
            `INSERT INTO deduction_rule_master 
             (organization_id, deduction_code, deduction_name, calc_type, rate, calc_basis, eligibility_ceiling, wage_ceiling, fixed_amount, is_statutory, is_active, display_order, notes)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [organization_id || 1, deduction_code, deduction_name, calc_type, rate || null, calc_basis || null, eligibility_ceiling || null, wage_ceiling || null, fixed_amount || null, is_statutory || 0, is_active || 1, display_order || 0, notes || null]
        );
        return result.insertId;
    }

    static async updateDeductionRule(id, data) {
        const { deduction_name, calc_type, rate, calc_basis, eligibility_ceiling, wage_ceiling, fixed_amount, is_statutory, is_active, display_order, notes } = data;
        const [result] = await pool.execute(
            `UPDATE deduction_rule_master SET 
                deduction_name = ?, calc_type = ?, rate = ?, calc_basis = ?, eligibility_ceiling = ?, 
                wage_ceiling = ?, fixed_amount = ?, is_statutory = ?, is_active = ?, display_order = ?, notes = ?
             WHERE rule_id = ?`,
            [deduction_name, calc_type, rate || null, calc_basis || null, eligibility_ceiling || null, wage_ceiling || null, fixed_amount || null, is_statutory || 0, is_active || 1, display_order || 0, notes || null, id]
        );
        return result.affectedRows;
    }

    static async deleteDeductionRule(id) {
        const [result] = await pool.execute('DELETE FROM deduction_rule_master WHERE rule_id = ?', [id]);
        return result.affectedRows;
    }

    // --- Tax Slabs ---
    static async getTaxSlabs() {
        const [rows] = await pool.execute('SELECT * FROM profession_tax_slab ORDER BY min_salary ASC');
        return rows;
    }

    static async createTaxSlab(data) {
        const { organization_id, state_code, min_salary, max_salary, monthly_tax, effective_from, effective_to } = data;
        const [result] = await pool.execute(
            `INSERT INTO profession_tax_slab (organization_id, state_code, min_salary, max_salary, monthly_tax, effective_from, effective_to)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [organization_id || 1, state_code || 'KL', min_salary, max_salary || null, monthly_tax, effective_from, effective_to || null]
        );
        return result.insertId;
    }

    static async updateTaxSlab(id, data) {
        const { state_code, min_salary, max_salary, monthly_tax, effective_from, effective_to } = data;
        const [result] = await pool.execute(
            `UPDATE profession_tax_slab SET 
                state_code = ?, min_salary = ?, max_salary = ?, monthly_tax = ?, effective_from = ?, effective_to = ?
             WHERE slab_id = ?`,
            [state_code || 'KL', min_salary, max_salary || null, monthly_tax, effective_from, effective_to || null, id]
        );
        return result.affectedRows;
    }

    static async deleteTaxSlab(id) {
        const [result] = await pool.execute('DELETE FROM profession_tax_slab WHERE slab_id = ?', [id]);
        return result.affectedRows;
    }

    // --- Employee Configs ---
    static async getSalaryStructure(employeeId) {
        const [rows] = await pool.execute(
            'SELECT * FROM salary_structure WHERE employee_id = ? ORDER BY effective_from DESC',
            [employeeId]
        );
        return rows;
    }

    static async saveSalaryStructure(employeeId, data) {
        const { basic_pay, hra, educational_allowance, special_allowance, naac_allowance, effective_from, created_by } = data;
        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();
            // Mark current current structures as 0
            await conn.execute('UPDATE salary_structure SET is_current = 0 WHERE employee_id = ?', [employeeId]);
            // Insert new current structure
            const [result] = await conn.execute(
                `INSERT INTO salary_structure (employee_id, basic_pay, hra, educational_allowance, special_allowance, naac_allowance, effective_from, is_current, created_by)
                 VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)`,
                [employeeId, basic_pay, hra || 0, educational_allowance || 0, special_allowance || 0, naac_allowance || 0, effective_from, created_by]
            );
            await conn.commit();
            return result.insertId;
        } catch (err) {
            await conn.rollback();
            throw err;
        } finally {
            conn.release();
        }
    }

    static async getDeductionConfigs(employeeId) {
        const [rows] = await pool.execute(
            `SELECT drm.rule_id, drm.deduction_code, drm.deduction_name, drm.is_statutory,
                    edc.config_id, COALESCE(edc.is_applicable, 0) AS is_applicable, edc.override_amount
             FROM deduction_rule_master drm
             LEFT JOIN employee_deduction_config edc ON drm.rule_id = edc.rule_id AND edc.employee_id = ?
             WHERE drm.is_active = 1`,
            [employeeId]
        );
        return rows;
    }

    static async saveDeductionConfig(employeeId, data) {
        const { rule_id, is_applicable, override_amount, effective_from } = data;
        const [result] = await pool.execute(
            `INSERT INTO employee_deduction_config (employee_id, rule_id, is_applicable, override_amount, effective_from)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE 
                is_applicable = VALUES(is_applicable),
                override_amount = VALUES(override_amount),
                effective_from = VALUES(effective_from)`,
            [employeeId, rule_id, is_applicable ? 1 : 0, override_amount || null, effective_from || new Date().toISOString().split('T')[0]]
        );
        return result;
    }

    static async getTdsConfig(employeeId) {
        const [rows] = await pool.execute(
            'SELECT * FROM employee_tds_config WHERE employee_id = ?',
            [employeeId]
        );
        return rows[0] || null;
    }

    static async saveTdsConfig(employeeId, data) {
        const { financial_year, tax_regime, taxable_components, tds_override_amount, tds_override_reason, declared_80c, declared_80d, declared_hra_exempt, declared_other } = data;
        const [result] = await pool.execute(
            `INSERT INTO employee_tds_config 
             (employee_id, financial_year, tax_regime, taxable_components, tds_override_amount, tds_override_reason, declared_80c, declared_80d, declared_hra_exempt, declared_other)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                tax_regime = VALUES(tax_regime),
                taxable_components = VALUES(taxable_components),
                tds_override_amount = VALUES(tds_override_amount),
                tds_override_reason = VALUES(tds_override_reason),
                declared_80c = VALUES(declared_80c),
                declared_80d = VALUES(declared_80d),
                declared_hra_exempt = VALUES(declared_hra_exempt),
                declared_other = VALUES(declared_other)`,
            [employeeId, financial_year || '2026-2027', tax_regime || 'new', taxable_components || 'basic_pay,hra,educational_allowance,special_allowance,naac_allowance', tds_override_amount || null, tds_override_reason || null, declared_80c || 0, declared_80d || 0, declared_hra_exempt || 0, declared_other || 0]
        );
        return result;
    }

    static async getBankAccounts(employeeId) {
        const [rows] = await pool.execute(
            'SELECT * FROM employee_bank_account WHERE employee_id = ?',
            [employeeId]
        );
        return rows;
    }

    static async saveBankAccount(employeeId, data) {
        const { bank_name, branch_name, account_number, ifsc_code, account_type, is_primary, is_active } = data;

        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();
            if (is_primary) {
                await conn.execute('UPDATE employee_bank_account SET is_primary = 0 WHERE employee_id = ?', [employeeId]);
            }
            const [result] = await conn.execute(
                `INSERT INTO employee_bank_account (employee_id, bank_name, branch_name, account_number, ifsc_code, account_type, is_primary, is_active)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE
                    bank_name = VALUES(bank_name),
                    branch_name = VALUES(branch_name),
                    account_number = VALUES(account_number),
                    ifsc_code = VALUES(ifsc_code),
                    account_type = VALUES(account_type),
                    is_primary = VALUES(is_primary),
                    is_active = VALUES(is_active)`,
                [employeeId, bank_name, branch_name, account_number, ifsc_code, account_type || 'savings', is_primary ? 1 : 0, is_active ? 1 : 0]
            );
            await conn.commit();
            return result;
        } catch (e) {
            await conn.rollback();
            throw e;
        } finally {
            conn.release();
        }
    }

    static async getLoans(employeeId) {
        const [rows] = await pool.execute(
            `SELECT el.*, e.employee_name AS approver_name
             FROM employee_loan el
             LEFT JOIN employee e ON el.approved_by = e.employee_id
             WHERE el.employee_id = ?`,
            [employeeId]
        );
        return rows;
    }

    static async createLoan(employeeId, data) {
        const { loan_type, loan_amount, reason, monthly_deduction, deduction_start_month, deduction_start_year } = data;
        const [result] = await pool.execute(
            `INSERT INTO employee_loan (employee_id, loan_type, loan_amount, reason, status, monthly_deduction, deduction_start_month, deduction_start_year, total_paid_amount)
             VALUES (?, ?, ?, ?, 'pending', ?, ?, ?, 0)`,
            [employeeId, loan_type, loan_amount, reason || null, monthly_deduction, deduction_start_month, deduction_start_year]
        );
        return result.insertId;
    }

    static async updateLoanStatus(loanId, data) {
        const { status, approved_by, remarks } = data;
        const [result] = await pool.execute(
            `UPDATE employee_loan SET 
                status = ?, approved_by = ?, approved_on = CURRENT_DATE(), remarks = ?
             WHERE loan_id = ?`,
            [status, approved_by || null, remarks || null, loanId]
        );
        return result.affectedRows;
    }

    // --- Processing Operations ---
    static async runPayroll(periodId, preparedBy, organizationId = 1) {
        const [rows] = await pool.execute(
            'CALL sp_run_payroll(?, ?, ?)',
            [organizationId, periodId, preparedBy]
        );
        return rows[0]?.[0] || { processed_count: 0 };
    }

    static async deletePayrollRun(periodId) {
        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();
            // Delete from payroll_approval_log first (to prevent foreign key violations if any)
            await conn.execute('DELETE FROM payroll_approval_log WHERE period_id = ?', [periodId]);
            // Then delete from salary_disbursement
            await conn.execute('DELETE FROM salary_disbursement WHERE period_id = ?', [periodId]);
            // Update payroll_period status back to 'draft'
            const [result] = await conn.execute('UPDATE payroll_period SET status = \'draft\' WHERE period_id = ?', [periodId]);
            await conn.commit();
            return result.affectedRows;
        } catch (e) {
            await conn.rollback();
            throw e;
        } finally {
            conn.release();
        }
    }

    static async actionPayrollPeriod(periodId, action, actionBy, remarks) {
        const [rows] = await pool.execute(
            'CALL sp_action_payroll_period(?, ?, ?, ?)',
            [periodId, action, actionBy, remarks || null]
        );
        return rows[0]?.[0] || { updated_disbursements: 0 };
    }

    static async getDisbursements(periodId) {
        const [rows] = await pool.execute(
            `SELECT sd.*, e.employee_name, e.employee_code, d.departmentname, des.designation AS designation_name
             FROM salary_disbursement sd
             JOIN employee e ON sd.employee_id = e.employee_id
             LEFT JOIN department d ON e.department_id = d.department_id
             LEFT JOIN designation des ON e.designation_id = des.designation_id
             WHERE sd.period_id = ?`,
            [periodId]
        );
        return rows;
    }

    static async getStatement(periodId) {
        const [disbursements] = await pool.execute(
            `SELECT sd.*, 
                    e.employee_name, 
                    e.employee_code, 
                    e.joining_date,
                    d.departmentname AS department_name, 
                    des.designation AS designation,
                    eba.bank_name,
                    eba.account_number,
                    eba.ifsc_code
             FROM salary_disbursement sd
             JOIN employee e ON sd.employee_id = e.employee_id
             LEFT JOIN department d ON e.department_id = d.department_id
             LEFT JOIN designation des ON e.designation_id = des.designation_id
             LEFT JOIN employee_bank_account eba ON sd.employee_id = eba.employee_id AND eba.is_primary = 1 AND eba.is_active = 1
             WHERE sd.period_id = ?`,
            [periodId]
        );
        return disbursements;
    }

    static async getLoanTracker() {
        const [rows] = await pool.execute(
            `SELECT el.*, e.employee_name, e.employee_code
             FROM employee_loan el
             JOIN employee e ON el.employee_id = e.employee_id
             ORDER BY el.created_on DESC`
        );
        return rows;
    }

    static async getApprovalLogs(periodId) {
        const [rows] = await pool.execute(
            `SELECT pal.*, e.employee_name AS actor_name,
                    CASE WHEN pal.action = 'edited' THEN emp.employee_name ELSE NULL END AS target_employee_name
             FROM payroll_approval_log pal
             LEFT JOIN employee e ON pal.action_by = e.employee_id
             LEFT JOIN salary_disbursement sd ON pal.disbursement_id = sd.disbursement_id
             LEFT JOIN employee emp ON sd.employee_id = emp.employee_id
             WHERE pal.period_id = ?
               AND (pal.action = 'edited'
                    OR pal.log_id IN (
                        SELECT MIN(log_id)
                        FROM payroll_approval_log
                        WHERE period_id = ? AND action != 'edited'
                        GROUP BY action, action_by, action_on, remarks
                    ))
             ORDER BY pal.action_on DESC, pal.log_id DESC`,
            [periodId, periodId]
        );
        return rows;
    }

    static async getLopDetails(periodId, employeeId) {
        // 1. Fetch period dates
        const [periods] = await pool.execute('SELECT start_date, end_date FROM payroll_period WHERE period_id = ?', [periodId]);
        if (periods.length === 0) return [];
        const { start_date, end_date } = periods[0];

        // 2. Check if there are any attendance records for this period
        const [attCountRows] = await pool.execute(
            'SELECT COUNT(*) AS count FROM attendance_daily WHERE employee_id = ? AND date BETWEEN ? AND ?',
            [employeeId, start_date, end_date]
        );
        const hasRecords = attCountRows[0].count > 0;

        if (hasRecords) {
            // Get records with LOP deduction
            const [rows] = await pool.execute(
                `SELECT date, deduction_days, status, shift_type 
                 FROM attendance_daily 
                 WHERE employee_id = ? AND date BETWEEN ? AND ? AND (deduction_days > 0 OR status = 'Absent')
                 ORDER BY date ASC`,
                [employeeId, start_date, end_date]
            );
            return rows.map(r => ({
                date: r.date,
                deduction_days: parseFloat(r.deduction_days || 0),
                reason: r.status === 'Absent' ? 'Absent' : `Deduction (${r.status})`,
                type: 'attendance_record'
            }));
        } else {
            // Calculate LOP days dynamically
            // Get all holidays in the period
            const [holidays] = await pool.execute(
                `SELECT holiday_start_date, holiday_end_date, holiday_name 
                 FROM holiday_master 
                 WHERE is_active = 1 AND (employee_id = -1 OR employee_id = ?) 
                   AND ((holiday_start_date <= ? AND holiday_end_date >= ?) OR (holiday_start_date BETWEEN ? AND ?) OR (holiday_end_date BETWEEN ? AND ?))`,
                [employeeId, end_date, start_date, start_date, end_date, start_date, end_date]
            );

            const isHoliday = (dateStr) => {
                const d = new Date(dateStr);
                // Check Sunday (d.getDay() === 0)
                if (d.getDay() === 0) return { isHoliday: true, name: 'Sunday' };
                // Check holiday_master
                for (const h of holidays) {
                    const start = new Date(h.holiday_start_date);
                    const end = new Date(h.holiday_end_date);
                    if (d >= start && d <= end) {
                        return { isHoliday: true, name: h.holiday_name };
                    }
                }
                return { isHoliday: false };
            };

            const lopDays = [];
            let curr = new Date(start_date);
            const stop = new Date(end_date);
            while (curr <= stop) {
                const dateStr = curr.toISOString().split('T')[0];
                const holidayCheck = isHoliday(dateStr);
                if (!holidayCheck.isHoliday) {
                    lopDays.push({
                        date: dateStr,
                        deduction_days: 1.0,
                        reason: 'Missing Attendance (Working Day)',
                        type: 'computed_lop'
                    });
                }
                curr.setDate(curr.getDate() + 1);
            }
            return lopDays;
        }
    }

    static async updateDisbursement(id, data, updatedBy) {
        const { basic_pay, hra, educational_allowance, special_allowance, naac_allowance, lop_days, tds, loan_emi, bus_fee } = data;

        // 1. Fetch original disbursement to retrieve original deductions_json and check applicability
        const [rows] = await pool.execute('SELECT * FROM salary_disbursement WHERE disbursement_id = ?', [id]);
        if (rows.length === 0) return 0;
        const old = rows[0];

        const oldDec = typeof old.deductions_json === 'string' ? JSON.parse(old.deductions_json) : (old.deductions_json || {});

        // Build diff for history tracking
        const diffs = [];
        const compareAndAdd = (name, oldVal, newVal) => {
            const o = parseFloat(oldVal || 0);
            const n = parseFloat(newVal || 0);
            if (o !== n) {
                diffs.push(`${name}: ${o} -> ${n}`);
            }
        };

        compareAndAdd('Basic Pay', old.basic_pay, basic_pay);
        compareAndAdd('HRA', old.hra, hra);
        compareAndAdd('Edu Allowance', old.educational_allowance, educational_allowance);
        compareAndAdd('Spec Allowance', old.special_allowance, special_allowance);
        compareAndAdd('NAAC Allowance', old.naac_allowance, naac_allowance);
        compareAndAdd('LOP Days', old.lop_days, lop_days);
        compareAndAdd('TDS', oldDec.TDS, tds);
        compareAndAdd('Loan EMI', oldDec.LoanEMI, loan_emi);
        compareAndAdd('Bus Fee', oldDec.BusFee, bus_fee);

        const remarksText = diffs.length > 0 ? `Edited: ${diffs.join(', ')}` : 'Edited (no values changed)';

        // 2. Perform recalculations
        const gross_salary = parseFloat(basic_pay) + parseFloat(hra) + parseFloat(educational_allowance) + parseFloat(special_allowance) + parseFloat(naac_allowance);

        // Fixed 30-day divisor for LOP deduction
        const lop_deduction = Math.round((gross_salary / 30) * parseFloat(lop_days) * 100) / 100;
        const payable_amount = Math.max(0, gross_salary - lop_deduction);

        // EPF Recalculation
        const hasEPF = (oldDec.EPF > 0 || oldDec.EPF_rate > 0);
        const epf_rate = oldDec.EPF_rate || 12.0;
        // EPF base is pro-rated earned basic pay, capped at 15000
        const epf_base = Math.min(15000, Math.round(parseFloat(basic_pay) * (1 - (parseFloat(lop_days) / 30)) * 100) / 100);
        const epf_amount = hasEPF ? Math.round(epf_base * (epf_rate / 100) * 100) / 100 : 0;

        // ESI Recalculation
        const hasESI = (oldDec.ESI > 0 || oldDec.ESI_rate > 0);
        const esi_rate = oldDec.ESI_rate || 0.75;
        const esi_base = payable_amount;
        const esi_amount = (hasESI && esi_base <= 21000) ? Math.round(esi_base * (esi_rate / 100) * 100) / 100 : 0;

        // Profession Tax Slab lookup
        const [ptRows] = await pool.execute(
            `SELECT COALESCE(monthly_tax, 0) AS pt_amount
             FROM profession_tax_slab
             WHERE ? >= min_salary AND (max_salary IS NULL OR ? <= max_salary)
             ORDER BY min_salary DESC LIMIT 1`,
            [payable_amount, payable_amount]
        );
        const pt_amount = ptRows[0]?.pt_amount || 0;

        // Total Deductions
        const total_deduction = epf_amount + esi_amount + parseFloat(tds || 0) + parseFloat(pt_amount || 0) + parseFloat(loan_emi || 0) + parseFloat(bus_fee || 0);

        const net_salary = Math.max(0, payable_amount - total_deduction);

        // Construct new JSON
        const deductions_json = JSON.stringify({
            ...oldDec,
            EPF: epf_amount,
            EPF_base: epf_base,
            EPF_rate: epf_rate,
            ESI: esi_amount,
            ESI_base: esi_base,
            ESI_rate: esi_rate,
            TDS: parseFloat(tds || 0),
            ProfessionTax: pt_amount,
            LoanEMI: parseFloat(loan_emi || 0),
            BusFee: parseFloat(bus_fee || 0),
            LOP_days: parseFloat(lop_days),
            LOP_deduction: lop_deduction,
            Gross_salary: gross_salary,
            Basic_pay: parseFloat(basic_pay),
            Payable_amount: payable_amount,
            Days_in_period: 30
        });

        // Update database row
        const [result] = await pool.execute(
            `UPDATE salary_disbursement SET
                basic_pay = ?,
                hra = ?,
                educational_allowance = ?,
                special_allowance = ?,
                naac_allowance = ?,
                gross_salary = ?,
                lop_days = ?,
                payable_amount = ?,
                deductions_json = ?,
                total_deduction = ?,
                net_salary = ?
             WHERE disbursement_id = ?`,
            [basic_pay, hra, educational_allowance, special_allowance, naac_allowance, gross_salary, lop_days, payable_amount, deductions_json, total_deduction, net_salary, id]
        );

        // Log edit event
        await pool.execute(
            `INSERT INTO payroll_approval_log (
                disbursement_id, period_id, action, action_by, action_on, remarks, previous_status, new_status
             ) VALUES (?, ?, 'edited', ?, NOW(), ?, ?, ?)`,
            [id, old.period_id, updatedBy || 999, remarksText, old.status, old.status]
        );

        return result.affectedRows;
    }

    // --- Workflow Config ---
    static async getWorkflowConfig() {
        const [rows] = await pool.execute(`
            SELECT pwc.*, ua.user_display_name, ua.email, emp.employee_name, emp.employee_code
            FROM payroll_workflow_config pwc
            LEFT JOIN user_accounts ua ON pwc.assigned_to_user_id = ua.user_accounts_id
            LEFT JOIN employee emp ON ua.employee_id = emp.employee_id
            ORDER BY pwc.level_number ASC
        `);
        return rows;
    }

    static async updateWorkflowConfig(levelId, assignedToUserId, assignedToRole) {
        const [result] = await pool.execute(
            `UPDATE payroll_workflow_config 
             SET assigned_to_user_id = ?, assigned_to_role = ?
             WHERE level_id = ?`,
            [assignedToUserId || null, assignedToRole || null, levelId]
        );
        return result.affectedRows;
    }

    static async getWorkflowUsers() {
        const [rows] = await pool.execute(`
            SELECT ua.user_accounts_id, ua.user_display_name, ua.email, r.role as role_name, emp.employee_name
            FROM user_accounts ua
            LEFT JOIN app_role r ON ua.role_id = r.role_id
            LEFT JOIN employee emp ON ua.employee_id = emp.employee_id
            WHERE ua.active = 1
            ORDER BY COALESCE(emp.employee_name, ua.user_display_name) ASC
        `);
        return rows;
    }

    static async getWorkflowRoles() {
        const [rows] = await pool.execute('SELECT role_id, role FROM app_role ORDER BY role ASC');
        return rows;
    }
}

module.exports = PayrollModel;
