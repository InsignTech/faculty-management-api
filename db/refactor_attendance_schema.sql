USE `staffdesk`;

-- 1. Add new column and modify existing ones to be consistent
ALTER TABLE attendance_daily 
ADD COLUMN onduty_shift_type ENUM('FullDay', 'FirstHalf', 'SecondHalf') DEFAULT NULL AFTER is_regularize_type;

-- 2. Migrate data from old columns to new ones (if data exists)
UPDATE attendance_daily SET onduty_shift_type = regularization_shift_type WHERE is_regularize_type = 'OnDuty';
-- If it was OnDuty, the regularization_shift_type column was likely used for it in previous logic.
-- We keep regularization_shift_type for 'Regularization' requests.
UPDATE attendance_daily SET regularization_shift_type = NULL WHERE is_regularize_type = 'OnDuty';

-- 3. Remove old columns
ALTER TABLE attendance_daily DROP COLUMN is_regularized;
ALTER TABLE attendance_daily DROP COLUMN is_regularize_type;

-- 4. Ensure consistency in other shift types
ALTER TABLE attendance_daily 
MODIFY COLUMN leave_shift_type ENUM('FullDay', 'FirstHalf', 'SecondHalf') DEFAULT NULL,
MODIFY COLUMN regularization_shift_type ENUM('FullDay', 'FirstHalf', 'SecondHalf') DEFAULT NULL;
