-- Test Data for Attendance Management System
USE `staffdesk`;

-- =============================================
-- 1. Insert Raw Logs (attendance_detail_log)
-- =============================================
-- Scenario: Employee 1 has multiple punches on March 25, 2026
INSERT INTO attendance_detail_log (employee_id, date, time) VALUES 
(1, '2026-03-25', '09:05:00'),
(1, '2026-03-25', '13:02:00'),
(1, '2026-03-25', '14:15:00'),
(1, '2026-03-25', '18:10:00');

-- Scenario: Employee 2 has multiple punches on March 25, 2026
INSERT INTO attendance_detail_log (employee_id, date, time) VALUES 
(2, '2026-03-25', '08:55:00'),
(2, '2026-03-25', '18:05:00');

-- Scenario: Only single punch for Employee 3 (needs regularization)
INSERT INTO attendance_detail_log (employee_id, date, time) VALUES 
(3, '2026-03-25', '09:15:00');

-- =============================================
-- 2. Process Logs
-- =============================================
CALL sp_process_attendance_logs('2026-03-25');

-- =============================================
-- 3. Insert Adjustments (attendance_adjustments)
-- =============================================

-- Pending Regularization for Employee 1
INSERT INTO attendance_adjustments (employee_id, type, date, punch_time, remarks, status)
VALUES (1, 'Regularization', '2026-03-24', '09:00:00', 'Forgot to punch in during client meeting', 'Pending');

-- Approved On-Duty for Employee 1
INSERT INTO attendance_adjustments (employee_id, type, date, punch_time, remarks, status, approved_by_id, approved_on)
VALUES (1, 'OnDuty', '2026-03-23', '10:00:00', 'Visit to manufacturing site', 'Approved', 1, NOW());

-- Rejected Regularization for Employee 2
INSERT INTO attendance_adjustments (employee_id, type, date, punch_time, remarks, status, approved_by_id, approved_on)
VALUES (2, 'Regularization', '2026-03-22', '09:30:00', 'Late due to traffic (Personal)', 'Rejected', 1, NOW());

-- =============================================
-- 4. Verification Check
-- =============================================
SELECT 'Summary of Processed Attendance' as info;
SELECT * FROM attendance WHERE date = '2026-03-25';

SELECT 'Summary of Adjustments' as info;
SELECT * FROM attendance_adjustments;
