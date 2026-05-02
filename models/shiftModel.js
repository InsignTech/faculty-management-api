const pool = require('../config/db');

class ShiftModel {
  // Get all global shifts (employee_id = -1)
  static async getGlobalShifts() {
    const [rows] = await pool.query(
      'SELECT * FROM shift_master WHERE employee_id = -1 ORDER BY shift_id ASC'
    );
    return rows;
  }

  // Get shifts for a specific employee
  static async getEmployeeShifts(employeeId) {
    const [rows] = await pool.query(
      'SELECT s.*, DATE_FORMAT(s.start_date, "%Y-%m-%d") as start_date, DATE_FORMAT(s.end_date, "%Y-%m-%d") as end_date, e.employee_name FROM shift_master s JOIN employee e ON s.employee_id = e.employee_id WHERE s.employee_id = ? ORDER BY s.start_date DESC',
      [employeeId]
    );
    return rows;
  }

  // Get all employee-specific shifts with optional search and pagination
  static async getAllEmployeeShifts({ search = '', page = 1, limit = 10 }) {
    const offset = (page - 1) * limit;
    
    // We want to paginate by GROUPS of shifts (3 shifts per assignment)
    // To keep it simple, we'll fetch rows with a limit that is a multiple of 3 if we assume 3 shifts per group
    // Or better: Paginate by unique (employee_id, start_date) groups
    
    let baseQuery = `
      FROM shift_master s 
      JOIN employee e ON s.employee_id = e.employee_id 
      WHERE s.employee_id != -1 
    `;
    let params = [];

    if (search) {
      baseQuery += ` AND (e.employee_name LIKE ? OR e.employee_code LIKE ?) `;
      params.push(`%${search}%`, `%${search}%`);
    }

    // Get total count of shifts (rows)
    const [countResult] = await pool.query(`SELECT COUNT(*) as total ${baseQuery}`, params);
    const total = countResult[0].total;

    // Get paginated shifts
    const [rows] = await pool.query(`
      SELECT s.*, DATE_FORMAT(s.start_date, "%Y-%m-%d") as start_date, DATE_FORMAT(s.end_date, "%Y-%m-%d") as end_date, e.employee_name, e.employee_code 
      ${baseQuery}
      ORDER BY s.created_on DESC 
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), parseInt(offset)]);

    return { shifts: rows, total };
  }

  // Update a global shift
  static async updateGlobalShift(shiftId, data) {
    const { start_time, end_time, start_grace_mins, end_grace_mins, modified_by } = data;
    const [result] = await pool.execute(
      `UPDATE shift_master 
       SET start_time = ?, end_time = ?, start_grace_mins = ?, end_grace_mins = ?, created_by = ?
       WHERE shift_id = ? AND employee_id = -1`,
      [start_time, end_time, start_grace_mins, end_grace_mins, modified_by, shiftId]
    );
    return result.affectedRows > 0;
  }

  // Bulk create 3 mandatory shifts for an employee
  static async assignEmployeeShifts(employeeId, fromDate, toDate, shifts, createdBy) {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // 1. Overlap Check
      // Check if any existing shift for this employee overlaps with the new date range
      const [overlaps] = await conn.query(
        `SELECT shift_id FROM shift_master 
         WHERE employee_id = ? 
         AND (
           (start_date <= ? AND (end_date IS NULL OR end_date >= ?))
           OR (start_date <= ? AND (end_date IS NULL OR end_date >= ?))
           OR (? <= start_date AND (end_date IS NULL OR ? >= end_date))
         )`,
        [employeeId, fromDate, fromDate, toDate, toDate, fromDate, toDate]
      );

      if (overlaps.length > 0) {
        throw new Error('Shift assignment overlaps with an existing date range for this employee.');
      }

      // 2. Insert the 3 shifts
      for (const shift of shifts) {
        const { type, start, end, grace_in, grace_out } = shift;
        await conn.execute(
          `INSERT INTO shift_master 
           (employee_id, start_date, end_date, shift_type, start_time, end_time, start_grace_mins, end_grace_mins, created_by)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [employeeId, fromDate, toDate || null, type, start, end, grace_in || 0, grace_out || 0, createdBy]
        );
      }

      await conn.commit();
      return true;
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  static async deleteEmployeeShiftGroup(employeeId, startDate, endDate) {
    let query = 'DELETE FROM shift_master WHERE employee_id = ? AND DATE(start_date) = DATE(?)';
    let params = [employeeId, startDate];

    if (endDate && endDate !== 'null') {
      query += ' AND DATE(end_date) = DATE(?)';
      params.push(endDate);
    } else {
      query += ' AND end_date IS NULL';
    }

    const [result] = await pool.query(query, params);
    return result.affectedRows;
  }
}

module.exports = ShiftModel;
