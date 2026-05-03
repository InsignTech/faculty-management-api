const pool = require('../config/db');

class HolidayModel {
  // Get all general holidays (employee_id = -1)
  static async getGeneralHolidays(year) {
    let query = 'SELECT *, DATE_FORMAT(holiday_start_date, "%Y-%m-%d") as holiday_start_date, DATE_FORMAT(holiday_end_date, "%Y-%m-%d") as holiday_end_date FROM holiday_master WHERE employee_id = -1';
    const params = [];
    
    if (year) {
      query += ' AND (YEAR(holiday_start_date) = ? OR YEAR(holiday_end_date) = ?)';
      params.push(year, year);
    }
    
    query += ' ORDER BY holiday_start_date ASC';
    const [rows] = await pool.query(query, params);
    return rows;
  }

  // Get all employee-specific holidays with search and pagination
  static async getEmployeeHolidays({ search = '', page = 1, limit = 10, year }) {
    const offset = (page - 1) * limit;
    let baseQuery = `
      FROM holiday_master h
      JOIN employee e ON h.employee_id = e.employee_id
      WHERE h.employee_id != -1
    `;
    const params = [];

    if (year) {
      baseQuery += ' AND (YEAR(h.holiday_start_date) = ? OR YEAR(h.holiday_end_date) = ?)';
      params.push(year, year);
    }

    if (search) {
      baseQuery += ' AND (e.employee_name LIKE ? OR e.employee_code LIKE ? OR h.holiday_name LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    const [countResult] = await pool.query(`SELECT COUNT(*) as total ${baseQuery}`, params);
    const total = countResult[0].total;

    const [rows] = await pool.query(`
      SELECT h.*, DATE_FORMAT(h.holiday_start_date, "%Y-%m-%d") as holiday_start_date, 
             DATE_FORMAT(h.holiday_end_date, "%Y-%m-%d") as holiday_end_date,
             e.employee_name, e.employee_code
      ${baseQuery}
      ORDER BY h.holiday_start_date DESC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), parseInt(offset)]);

    return { holidays: rows, total };
  }

  static async saveHoliday(holidayData) {
    const { 
      holiday_id, employee_id, holiday_name, holiday_start_date, 
      holiday_end_date, holiday_type, description, is_active 
    } = holidayData;

    if (holiday_id) {
      const [result] = await pool.execute(
        `UPDATE holiday_master 
         SET employee_id = ?, holiday_name = ?, holiday_start_date = ?, holiday_end_date = ?, 
             holiday_type = ?, description = ?, is_active = ?, updated_on = NOW()
         WHERE holiday_id = ?`,
        [employee_id, holiday_name, holiday_start_date, holiday_end_date, holiday_type, description, is_active, holiday_id]
      );
      return result.affectedRows > 0;
    } else {
      const [result] = await pool.execute(
        `INSERT INTO holiday_master 
         (employee_id, holiday_name, holiday_start_date, holiday_end_date, holiday_type, description, is_active, created_on)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
        [employee_id, holiday_name, holiday_start_date, holiday_end_date, holiday_type, description, is_active]
      );
      return result.insertId;
    }
  }

  static async deleteHoliday(id) {
    const [result] = await pool.execute('DELETE FROM holiday_master WHERE holiday_id = ?', [id]);
    return result.affectedRows > 0;
  }

  static async getUpcomingHolidays(employeeId) {
    const query = `
      SELECT *, 
             DATE_FORMAT(holiday_start_date, "%Y-%m-%d") as holiday_start_date, 
             DATE_FORMAT(holiday_end_date, "%Y-%m-%d") as holiday_end_date 
      FROM holiday_master 
      WHERE (employee_id = -1 OR employee_id = ?) 
      AND holiday_type != 'WeekEnd'
      AND holiday_start_date >= CURDATE()
      AND is_active = 1
      ORDER BY holiday_start_date ASC, employee_id DESC
      LIMIT 5
    `;
    const [rows] = await pool.query(query, [employeeId]);
    return rows;
  }

  static async getPersonalHolidays(employeeId, year) {
    let query = `
      SELECT *, 
             DATE_FORMAT(holiday_start_date, "%Y-%m-%d") as holiday_start_date, 
             DATE_FORMAT(holiday_end_date, "%Y-%m-%d") as holiday_end_date 
      FROM holiday_master 
      WHERE (employee_id = -1 OR employee_id = ?) 
      AND is_active = 1
    `;
    const params = [employeeId];

    if (year) {
      query += ' AND (YEAR(holiday_start_date) = ? OR YEAR(holiday_end_date) = ?)';
      params.push(year, year);
    }

    query += ' ORDER BY holiday_start_date ASC';
    const [rows] = await pool.query(query, params);
    return rows;
  }
}

module.exports = HolidayModel;
