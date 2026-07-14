DROP PROCEDURE IF EXISTS `sp_get_user_auth_details`;

DELIMITER ;;
CREATE PROCEDURE `sp_get_user_auth_details`(
    IN p_email VARCHAR(255)
)
BEGIN
    SELECT 
        ua.user_accounts_id,
        ua.user_display_name,
        ua.user_password,
        ua.email,
        COALESCE(e.role_id, ua.role_id) AS role_id,
        ua.employee_id,
        ua.active AS user_active,
        r.role AS role_name
    FROM user_accounts ua
    LEFT JOIN employee e
        ON ua.employee_id = e.employee_id
    LEFT JOIN app_role r
        ON r.role_id = COALESCE(e.role_id, ua.role_id)
    WHERE ua.email = p_email
      AND ua.active = 1
      AND (ua.employee_id IS NULL OR e.active = 1);
END ;;
DELIMITER ;
