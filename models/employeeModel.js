const pool = require('../config/db');
const bcrypt = require('bcryptjs');
const UserModel = require('./userModel');

class EmployeeModel {
  static async getPrincipalId() {
    try {
      const [rows] = await pool.query(`
        SELECT e.employee_id 
        FROM employee e 
        JOIN app_role r ON e.role_id = r.role_id 
        WHERE r.role IN ('Principal', 'principal') 
        LIMIT 1
      `);
      return rows.length > 0 ? rows[0].employee_id : null;
    } catch (err) {
      console.error('Error fetching Principal ID:', err);
      return null;
    }
  }

  static async create(data) {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      let reportingManagerId = data.reporting_manager_id || data.manager_id || null;

      // If no manager specified, try to find the Principal
      if (!reportingManagerId) {
        reportingManagerId = await this.getPrincipalId();
      }

      const [rows] = await conn.execute(
        'CALL sp_create_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          data.organization_id || 1,
          data.employee_code || '',
          data.employee_name || '',
          data.email || '',
          data.employee_role || 0,
          data.designation_id || 0,
          reportingManagerId,
          data.joining_date || null,
          data.active !== undefined ? data.active : 1,
          data.created_by || 'admin',
          data.department_id || 0,
          data.basic_pay || 0.00
        ]
      );
      const employee = rows[0][0];

      // Create user account for new employee
      if (employee && employee.employee_id && data.email) {
        const defaultPassword = `${data.employee_code || 'User'}@123`;
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(defaultPassword, salt);

        await conn.execute(
          `INSERT INTO user_accounts 
          (user_display_name, email, user_password, role_id, employee_id, active, created_on, created_by) 
          VALUES (?, ?, ?, ?, ?, 1, NOW(), 'system')`,
          [data.employee_name, data.email, hashedPassword, data.employee_role || 1, employee.employee_id]
        );
      }

      
      // Update personal details
      await conn.query(
        `UPDATE employee SET 
          title = ?, gender = ?, dob = ?, marital_status = ?, nationality = ?, 
          blood_group = ?, place_of_birth = ?, state_of_birth = ?, religion = ?, 
          identification_mark = ?, mother_tongue = ? 
         WHERE employee_id = ?`,
         [
           data.title || null, data.gender || null, data.dob || null, data.marital_status || null, data.nationality || null,
           data.blood_group || null, data.place_of_birth || null, data.state_of_birth || null, data.religion || null,
           data.identification_mark || null, data.mother_tongue || null,
           employee.employee_id
         ]
      );

      // Insert personal IDs
      await conn.query(
        `INSERT INTO employee_personal_ids 
         (employee_id, aadhar_number, aadhar_file, pan_number, pan_file, passport_number, passport_file, 
          voter_id_number, voter_id_file, driving_licence_number, driving_licence_file, uan_number, uan_file)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
         [
           employee.employee_id,
           data.personal_ids?.aadhar_number || null, data.personal_ids?.aadhar_file || null,
           data.personal_ids?.pan_number || null, data.personal_ids?.pan_file || null,
           data.personal_ids?.passport_number || null, data.personal_ids?.passport_file || null,
           data.personal_ids?.voter_id_number || null, data.personal_ids?.voter_id_file || null,
           data.personal_ids?.driving_licence_number || null, data.personal_ids?.driving_licence_file || null,
           data.personal_ids?.uan_number || null, data.personal_ids?.uan_file || null
         ]
      );

      await conn.commit();
      return employee;
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  static async getAll(limit = 10, offset = 0) {
    const query = `
      SELECT 
          e.*,
          d.departmentname,
          r.role AS role_name,
          des.designation AS designation_name,
          m.employee_name AS manager_name,
          mr.role AS manager_role
      FROM employee e
      LEFT JOIN department d ON e.department_id = d.department_id
      LEFT JOIN app_role r ON e.role_id = r.role_id
      LEFT JOIN designation des ON e.designation_id = des.designation_id
      LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
      LEFT JOIN app_role mr ON m.role_id = mr.role_id
      ORDER BY e.employee_id DESC
      LIMIT ? OFFSET ?
    `;
    const [rows] = await pool.execute(query, [limit.toString(), offset.toString()]);
    return rows;
  }

  static async getFiltered(searchTerm = '', roleId = 0, limit = 10, offset = 0, managerId = 0, myManagerId = 0, activeOnly = true) {
    const query = `
    SELECT 
        e.*,
        d.departmentname,
        r.role AS role_name,
        des.designation AS designation_name,
        m.employee_name AS manager_name,
        mr.role AS manager_role,
        CASE WHEN e.employee_id = ? THEN 1 ELSE 0 END as is_my_manager
    FROM employee e
    LEFT JOIN department d ON e.department_id = d.department_id
    LEFT JOIN app_role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
    LEFT JOIN app_role mr ON m.role_id = mr.role_id
    WHERE 
        (? = '' OR e.employee_name LIKE ? OR e.employee_code LIKE ?)
        AND (? = 0 OR e.role_id = ?)
        AND (
          (? = 0 AND ? = 0) -- Admin view
          OR (e.reporting_manager_id = ?) -- Reports
          OR (e.employee_id = ? AND ? != 0) -- My Manager
        )
        AND (? = 0 OR e.active = 1)
    ORDER BY e.employee_id DESC
    LIMIT ? OFFSET ?
  `;

    const term = searchTerm || '';
    const likeTerm = `%${term}%`;
    const rId = parseInt(roleId) || 0;
    const mId = parseInt(managerId) || 0;
    const reportToId = parseInt(myManagerId) || 0;
    const aOnly = activeOnly ? 1 : 0;
    const v_limit = parseInt(limit) || 10;
    const v_offset = parseInt(offset) || 0;

    const [rows] = await pool.query(query, [
      reportToId,
      term, likeTerm, likeTerm,
      rId, rId,
      mId, reportToId,
      mId,
      reportToId, reportToId,
      aOnly,
      v_limit,
      v_offset
    ]);

    return rows;
  }

  static async getTotalCount(searchTerm = '', roleId = 0, managerId = 0, myManagerId = 0, activeOnly = true) {
    const query = `
    SELECT COUNT(*) as total
    FROM employee e
    WHERE 
        (? = '' OR e.employee_name LIKE ? OR e.employee_code LIKE ?)
        AND (? = 0 OR e.role_id = ?)
        AND (
          (? = 0 AND ? = 0) -- Admin view
          OR (e.reporting_manager_id = ?) -- Reports
          OR (e.employee_id = ? AND ? != 0) -- My Manager
        )
        AND (? = 0 OR e.active = 1)
  `;

    const term = searchTerm || '';
    const likeTerm = `%${term}%`;
    const rId = parseInt(roleId) || 0;
    const mId = parseInt(managerId) || 0;
    const reportToId = parseInt(myManagerId) || 0;
    const aOnly = activeOnly ? 1 : 0;

    const [rows] = await pool.query(query, [
      term, likeTerm, likeTerm,
      rId, rId,
      mId, reportToId,
      mId,
      reportToId, reportToId,
      aOnly
    ]);

    return rows[0].total;
  }

  static async getPotentialManagers(searchTerm = '', departmentId = 0, excludeId = 0) {
    const [rows] = await pool.execute('CALL sp_get_potential_managers(?, ?, ?)', [
      searchTerm || '',
      departmentId || 0,
      excludeId || 0
    ]);
    return rows[0];
  }

  static async getById(id) {
    const [rows] = await pool.execute('CALL sp_get_employee_by_id(?)', [id]);
    let emp = rows[0][0];
    if (emp) {
        const [idRows] = await pool.execute('SELECT * FROM employee_personal_ids WHERE employee_id = ?', [id]);
        if (idRows.length > 0) {
            emp.personal_ids = idRows[0];
        }
    }
    return emp;
  }

  static async update(id, data) {
    const [rows] = await pool.query(
      'CALL sp_update_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        data.organization_id || 1,
        data.employee_code || '',
        data.employee_name || '',
        data.email || '',
        data.employee_role || 0,
        data.designation_id || 0,
        data.reporting_manager_id || null,
        data.joining_date || null,
        data.active !== undefined ? data.active : 1,
        data.modified_by || 'admin',
        data.department_id || 0,
        data.basic_pay || 0.00
      ]
    );

    const result = rows[0][0];

    // Email handled separately ✔
    if (data.email) {
      try {
        await UserModel.updateEmailByEmployeeId(id, data.email);
      } catch (err) {
        console.error('Failed to sync email:', err.message);
      }
    }

    
    // Update personal details
    await pool.query(
      `UPDATE employee SET 
        title = COALESCE(?, title), gender = COALESCE(?, gender), dob = COALESCE(?, dob), 
        marital_status = COALESCE(?, marital_status), nationality = COALESCE(?, nationality), 
        blood_group = COALESCE(?, blood_group), place_of_birth = COALESCE(?, place_of_birth), 
        state_of_birth = COALESCE(?, state_of_birth), religion = COALESCE(?, religion), 
        identification_mark = COALESCE(?, identification_mark), mother_tongue = COALESCE(?, mother_tongue)
       WHERE employee_id = ?`,
       [
         data.title !== undefined ? data.title : null, 
         data.gender !== undefined ? data.gender : null, 
         data.dob !== undefined ? data.dob : null, 
         data.marital_status !== undefined ? data.marital_status : null, 
         data.nationality !== undefined ? data.nationality : null,
         data.blood_group !== undefined ? data.blood_group : null, 
         data.place_of_birth !== undefined ? data.place_of_birth : null, 
         data.state_of_birth !== undefined ? data.state_of_birth : null, 
         data.religion !== undefined ? data.religion : null,
         data.identification_mark !== undefined ? data.identification_mark : null, 
         data.mother_tongue !== undefined ? data.mother_tongue : null,
         id
       ]
    );

    if (data.personal_ids) {
        await pool.query(
          `INSERT INTO employee_personal_ids 
           (employee_id, aadhar_number, aadhar_file, pan_number, pan_file, passport_number, passport_file, 
            voter_id_number, voter_id_file, driving_licence_number, driving_licence_file, uan_number, uan_file)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE 
           aadhar_number=COALESCE(VALUES(aadhar_number), aadhar_number), aadhar_file=COALESCE(VALUES(aadhar_file), aadhar_file),
           pan_number=COALESCE(VALUES(pan_number), pan_number), pan_file=COALESCE(VALUES(pan_file), pan_file),
           passport_number=COALESCE(VALUES(passport_number), passport_number), passport_file=COALESCE(VALUES(passport_file), passport_file),
           voter_id_number=COALESCE(VALUES(voter_id_number), voter_id_number), voter_id_file=COALESCE(VALUES(voter_id_file), voter_id_file),
           driving_licence_number=COALESCE(VALUES(driving_licence_number), driving_licence_number), driving_licence_file=COALESCE(VALUES(driving_licence_file), driving_licence_file),
           uan_number=COALESCE(VALUES(uan_number), uan_number), uan_file=COALESCE(VALUES(uan_file), uan_file)`,
           [
             id,
             (data.personal_ids.aadhar_number !== undefined && data.personal_ids.aadhar_number !== '') ? data.personal_ids.aadhar_number : null, 
             (data.personal_ids.aadhar_file !== undefined && data.personal_ids.aadhar_file !== '') ? data.personal_ids.aadhar_file : null,
             (data.personal_ids.pan_number !== undefined && data.personal_ids.pan_number !== '') ? data.personal_ids.pan_number : null, 
             (data.personal_ids.pan_file !== undefined && data.personal_ids.pan_file !== '') ? data.personal_ids.pan_file : null,
             (data.personal_ids.passport_number !== undefined && data.personal_ids.passport_number !== '') ? data.personal_ids.passport_number : null, 
             (data.personal_ids.passport_file !== undefined && data.personal_ids.passport_file !== '') ? data.personal_ids.passport_file : null,
             (data.personal_ids.voter_id_number !== undefined && data.personal_ids.voter_id_number !== '') ? data.personal_ids.voter_id_number : null, 
             (data.personal_ids.voter_id_file !== undefined && data.personal_ids.voter_id_file !== '') ? data.personal_ids.voter_id_file : null,
             (data.personal_ids.driving_licence_number !== undefined && data.personal_ids.driving_licence_number !== '') ? data.personal_ids.driving_licence_number : null, 
             (data.personal_ids.driving_licence_file !== undefined && data.personal_ids.driving_licence_file !== '') ? data.personal_ids.driving_licence_file : null,
             (data.personal_ids.uan_number !== undefined && data.personal_ids.uan_number !== '') ? data.personal_ids.uan_number : null, 
             (data.personal_ids.uan_file !== undefined && data.personal_ids.uan_file !== '') ? data.personal_ids.uan_file : null
           ]
        );
    }

    return result;

  }

  static async delete(id) {
    await pool.execute('CALL sp_delete_employee(?)', [id]);
    return true;
  }

  static async updateReportingManager(id, managerId) {
    const [result] = await pool.execute(
      'UPDATE employee SET reporting_manager_id = ? WHERE employee_id = ?',
      [managerId || null, id]
    );
    return result;
  }

  static async updateProfilePicture(id, fileName) {
    const [result] = await pool.execute(
      'UPDATE employee SET profile_picture = ? WHERE employee_id = ?',
      [fileName || null, id]
    );
    return result;
  }

  static async getSubordinates(managerId) {
    const query = `
      WITH RECURSIVE subordinates AS (
          SELECT employee_id, employee_name, employee_code, reporting_manager_id, role_id, department_id, designation_id, email
          FROM employee
          WHERE reporting_manager_id = ?
          UNION ALL
          SELECT e.employee_id, e.employee_name, e.employee_code, e.reporting_manager_id, e.role_id, e.department_id, e.designation_id, e.email
          FROM employee e
          INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
      )
      SELECT 
        s.*,
        d.departmentname,
        r.role AS role_name,
        des.designation AS designation_name
      FROM subordinates s
      LEFT JOIN department d ON s.department_id = d.department_id
      LEFT JOIN app_role r ON s.role_id = r.role_id
      LEFT JOIN designation des ON s.designation_id = des.designation_id
      ORDER BY s.employee_name ASC;
    `;
    const [rows] = await pool.execute(query, [managerId]);
    return rows;
  }

  static async isSubordinate(managerId, targetId) {
    if (!managerId || !targetId) return false;
    const query = `
      WITH RECURSIVE subordinates AS (
          SELECT employee_id
          FROM employee
          WHERE reporting_manager_id = ?
          UNION ALL
          SELECT e.employee_id
          FROM employee e
          INNER JOIN subordinates s ON e.reporting_manager_id = s.employee_id
      )
      SELECT COUNT(*) as count FROM subordinates WHERE employee_id = ?;
    `;
    const [rows] = await pool.execute(query, [managerId, targetId]);
    return rows[0].count > 0;
  }
}

module.exports = EmployeeModel;
