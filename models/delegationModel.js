const pool = require('../config/db');

class DelegationModel {
  static async create(delegateId, targetId, createdBy) {
    if (parseInt(delegateId) === parseInt(targetId)) {
      throw new Error('An employee cannot be delegated to themselves.');
    }

    const [result] = await pool.query(
      `INSERT INTO employee_delegation (delegate_employee_id, target_employee_id, created_by)
       VALUES (?, ?, ?)`,
      [delegateId, targetId, createdBy]
    );
    return { delegation_id: result.insertId };
  }

  static async delete(delegationId) {
    await pool.query(
      `DELETE FROM employee_delegation WHERE delegation_id = ?`,
      [delegationId]
    );
    return true;
  }

  static async getAll() {
    const [rows] = await pool.query(`
      SELECT 
          ed.delegation_id,
          ed.delegate_employee_id,
          d.employee_name AS delegate_name,
          d.employee_code AS delegate_code,
          ed.target_employee_id,
          t.employee_name AS target_name,
          t.employee_code AS target_code,
          ed.created_by,
          ed.created_on
      FROM employee_delegation ed
      JOIN employee d ON ed.delegate_employee_id = d.employee_id
      JOIN employee t ON ed.target_employee_id = t.employee_id
      ORDER BY ed.delegation_id DESC
    `);
    return rows;
  }

  static async getDelegatedTargetsForEmployee(delegateId) {
    const [rows] = await pool.query(`
      SELECT 
          e.employee_id AS id,
          e.employee_name AS name,
          e.employee_code AS code,
          r.role AS role_name
      FROM employee_delegation ed
      JOIN employee e ON ed.target_employee_id = e.employee_id
      LEFT JOIN app_role r ON e.role_id = r.role_id
      WHERE ed.delegate_employee_id = ? AND ed.is_active = 1 AND e.active = 1
      ORDER BY e.employee_name ASC
    `, [delegateId]);
    return rows;
  }

  static async checkDelegationExists(delegateId, targetId) {
    const [rows] = await pool.query(`
      SELECT 1 FROM employee_delegation 
      WHERE delegate_employee_id = ? AND target_employee_id = ? AND is_active = 1
      LIMIT 1
    `, [delegateId, targetId]);
    return rows.length > 0;
  }
}

module.exports = DelegationModel;
