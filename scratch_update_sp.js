const pool = require('./config/db');

async function updateSP() {
  const sql = `
    DROP PROCEDURE IF EXISTS sp_get_potential_managers;
    CREATE PROCEDURE sp_get_potential_managers(
        IN p_search_term VARCHAR(255),
        IN p_department_id INT,
        IN p_exclude_employee_id INT
    )
    BEGIN
        SELECT 
            e.employee_id,
            e.employee_name AS name,
            d.departmentname AS dept,
            e.department_id,
            r.role AS role_name
        FROM employee e
        LEFT JOIN department d ON e.department_id = d.department_id
        LEFT JOIN app_role r ON e.role_id = r.role_id
        WHERE 
            e.employee_id != p_exclude_employee_id
            AND e.active = 1
            AND (p_search_term IS NULL OR p_search_term = '' OR e.employee_name LIKE CONCAT('%', p_search_term, '%'))
            AND (p_department_id IS NULL OR p_department_id = 0 OR e.department_id = p_department_id)
        ORDER BY e.employee_name ASC;
    END;
  `;

  try {
    // Split by ; and run separately if needed, but MySQL allows multiple statements if enabled
    // However, usually we should run them one by one.
    await pool.query("DROP PROCEDURE IF EXISTS sp_get_potential_managers");
    await pool.query(`
      CREATE PROCEDURE sp_get_potential_managers(
          IN p_search_term VARCHAR(255),
          IN p_department_id INT,
          IN p_exclude_employee_id INT
      )
      BEGIN
          SELECT 
              e.employee_id,
              e.employee_name AS name,
              d.departmentname AS dept,
              e.department_id,
              r.role AS role_name
          FROM employee e
          LEFT JOIN department d ON e.department_id = d.department_id
          LEFT JOIN app_role r ON e.role_id = r.role_id
          WHERE 
              e.employee_id != p_exclude_employee_id
              AND e.active = 1
              AND (p_search_term IS NULL OR p_search_term = '' OR e.employee_name LIKE CONCAT('%', p_search_term, '%'))
              AND (p_department_id IS NULL OR p_department_id = 0 OR e.department_id = p_department_id)
          ORDER BY e.employee_name ASC;
      END
    `);
    console.log('Stored Procedure sp_get_potential_managers updated successfully');
    process.exit(0);
  } catch (err) {
    console.error('Error updating Stored Procedure:', err);
    process.exit(1);
  }
}

updateSP();
