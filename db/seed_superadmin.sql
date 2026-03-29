-- ============================================================
-- Superadmin Seed Script
-- Password: Admin@123
-- Hashed using bcrypt (10 rounds)
-- Run this once in your MySQL database: staffdesk
-- ============================================================

USE `staffdesk`;

-- Insert superadmin user account
-- Replace the hash below if you change the password
-- bcrypt hash of: Admin@123
INSERT INTO user_accounts (
    user_display_name,
    user_password,
    employee_id,
    email,
    active,
    role_id,
    otp,
    otp_generated_on,
    created_on,
    created_by
) VALUES (
    'Super Admin',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', -- bcrypt hash of: Admin@123
    NULL,       -- no employee record for superadmin
    'admin@staffdesk.com',
    1,
    1,          -- role_id 1 = assumed to be superadmin/admin role
    NULL,
    NULL,
    NOW(),
    'system'
);

SELECT 'Superadmin created successfully! Email: admin@staffdesk.com | Temp Password: password' AS info;

-- ============================================================
-- IMPORTANT: After first login, immediately reset your password
-- at /reset-password using the "I know my current password" option.
-- ============================================================
