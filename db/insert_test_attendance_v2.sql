-- Test Attendance Data (Restructured for punch_time)
USE `staffdesk`;

-- Clear existing raw logs to avoid duplicate errors during testing
SET SQL_SAFE_UPDATES = 0;
TRUNCATE TABLE attendance_detail_log;
TRUNCATE TABLE attendance;
SET SQL_SAFE_UPDATES = 1;

-- 1. Insert Raw Logs for multiple days
INSERT INTO attendance_detail_log (employee_id, punch_time) VALUES 
-- Employee 1: Perfect attendance for 3 days
(1, '2026-04-03 08:55:00'), (1, '2026-04-03 18:05:00'),
(1, '2026-04-04 08:58:00'), (1, '2026-04-04 18:02:00'),
(1, '2026-04-05 08:50:00'), (1, '2026-04-05 18:10:00'),

-- Employee 2: Late arrivals (> 9:15 AM)
(2, '2026-04-03 09:45:00'), (2, '2026-04-03 18:00:00'),
(2, '2026-04-04 09:20:00'), (2, '2026-04-04 18:15:00'),
(2, '2026-04-05 09:35:00'), (2, '2026-04-05 18:05:00'),

-- Employee 3: Single punches / Early departures (< 4:05 PM)
(3, '2026-04-03 09:00:00'), -- Single punch, no out
(3, '2026-04-04 09:05:00'), (3, '2026-04-04 15:30:00'), -- Early departure
(3, '2026-04-05 08:30:00'); -- Single punch, no out

-- 2. Process the logs for those dates
CALL sp_process_attendance_logs('2026-04-03');
CALL sp_process_attendance_logs('2026-04-04');
CALL sp_process_attendance_logs('2026-04-05');

-- 3. Verification
SELECT 'Processed Attendance summary' AS info;
SELECT a.*, e.employee_name 
FROM attendance a 
JOIN employee e ON a.employee_id = e.employee_id
ORDER BY a.date DESC, a.employee_id ASC;
