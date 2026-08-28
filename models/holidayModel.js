const pool = require('../config/db');

class HolidayModel {
  static async getById(id) {
    const [rows] = await pool.query('SELECT *, DATE_FORMAT(holiday_start_date, "%Y-%m-%d") as holiday_start_date, DATE_FORMAT(holiday_end_date, "%Y-%m-%d") as holiday_end_date FROM holiday_master WHERE holiday_id = ?', [id]);
    return rows[0] || null;
  }

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
  static async getEmployeeHolidays({ search = '', page = 1, limit = 10, year, role_id, date }) {
    const offset = (page - 1) * limit;
    let baseQuery = `
      FROM holiday_master h
      JOIN employee e ON h.employee_id = e.employee_id
      LEFT JOIN app_role r ON e.role_id = r.role_id
      WHERE h.employee_id != -1 AND e.active = 1
    `;
    const params = [];

    if (year) {
      baseQuery += ' AND (YEAR(h.holiday_start_date) = ? OR YEAR(h.holiday_end_date) = ?)';
      params.push(year, year);
    }

    if (role_id && role_id !== 'all') {
      baseQuery += ' AND e.role_id = ?';
      params.push(role_id);
    }

    if (date) {
      baseQuery += ' AND ? BETWEEN h.holiday_start_date AND h.holiday_end_date';
      params.push(date);
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
             e.employee_name, e.employee_code, r.role as employee_role
      ${baseQuery}
      ORDER BY h.holiday_start_date ASC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), parseInt(offset)]);

    return { holidays: rows, total };
  }

  static async saveHoliday(holidayData) {
    const { 
      holiday_id, employee_id, employee_ids, holiday_name, holiday_start_date, 
      holiday_end_date, holiday_type, description, is_active 
    } = holidayData;

    // Handle batch assignment for multiple employees
    if (!holiday_id && Array.isArray(employee_ids) && employee_ids.length > 0) {
      const results = [];
      for (const emp_id of employee_ids) {
        try {
          const result = await this.saveHoliday({
            holiday_id,
            employee_id: emp_id,
            holiday_name,
            holiday_start_date,
            holiday_end_date: holiday_end_date || holiday_start_date,
            holiday_type,
            description,
            is_active: is_active !== undefined ? is_active : 1
          });
          results.push({ employee_id: emp_id, success: true, result });
        } catch (error) {
          // Gracefully handle duplicate keys
          if (error.code === 'ER_DUP_ENTRY' || error.errno === 1062) {
            results.push({ employee_id: emp_id, success: false, reason: 'Duplicate entry ignored' });
          } else {
            throw error;
          }
        }
      }
      return results;
    }

    let successOrId;
    if (holiday_id) {
      const [result] = await pool.execute(
        `UPDATE holiday_master 
         SET employee_id = ?, holiday_name = ?, holiday_start_date = ?, holiday_end_date = ?, 
             holiday_type = ?, description = ?, is_active = ?, updated_on = NOW()
         WHERE holiday_id = ?`,
        [employee_id, holiday_name, holiday_start_date, holiday_end_date, holiday_type, description, is_active, holiday_id]
      );
      successOrId = result.affectedRows > 0;
    } else {
      const [result] = await pool.execute(
        `INSERT INTO holiday_master 
         (employee_id, holiday_name, holiday_start_date, holiday_end_date, holiday_type, description, is_active, created_on)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
        [employee_id, holiday_name, holiday_start_date, holiday_end_date, holiday_type, description, is_active]
      );
      successOrId = result.insertId;
    }

    // Trigger attendance rebuild for the holiday date range
    try {
      const start = holiday_start_date;
      const end = holiday_end_date || holiday_start_date;
      const msPerDay = 24 * 60 * 60 * 1000;
      const startDate = new Date(start);
      const endDate = new Date(end);
      for (let d = new Date(startDate); d <= endDate; d = new Date(d.getTime() + msPerDay)) {
        const dateStr = d.toISOString().split('T')[0];
        await pool.execute('CALL sp_process_attendance_shiftwise(?)', [dateStr]);
      }
    } catch (err) {
      console.error('Failed to rebuild attendance after saving holiday:', err);
    }

    return successOrId;
  }

  static async deleteHoliday(id) {
    const holiday = await this.getById(id);
    if (!holiday) return false;

    const [result] = await pool.execute('DELETE FROM holiday_master WHERE holiday_id = ?', [id]);
    const success = result.affectedRows > 0;

    if (success) {
      try {
        const msPerDay = 24 * 60 * 60 * 1000;
        const startDate = new Date(holiday.holiday_start_date);
        const endDate = new Date(holiday.holiday_end_date);
        for (let d = new Date(startDate); d <= endDate; d = new Date(d.getTime() + msPerDay)) {
          const dateStr = d.toISOString().split('T')[0];
          await pool.execute('CALL sp_process_attendance_shiftwise(?)', [dateStr]);
        }
      } catch (err) {
        console.error('Failed to rebuild attendance after deleting holiday:', err);
      }
    }

    return success;
  }

  static async deleteBulkHolidays({ date, role_id, year }) {
    let query = 'DELETE h FROM holiday_master h';
    const params = [];

    if (role_id && role_id !== 'all') {
      query = `
        DELETE h FROM holiday_master h
        JOIN employee e ON h.employee_id = e.employee_id
      `;
    }

    query += ' WHERE h.employee_id != -1';

    if (date) {
      query += ' AND ? BETWEEN h.holiday_start_date AND h.holiday_end_date';
      params.push(date);
    }

    if (role_id && role_id !== 'all') {
      query += ' AND e.role_id = ?';
      params.push(role_id);
    }

    if (year) {
      query += ' AND (YEAR(h.holiday_start_date) = ? OR YEAR(h.holiday_end_date) = ?)';
      params.push(year, year);
    }

    const [result] = await pool.query(query, params);
    return result.affectedRows;
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
