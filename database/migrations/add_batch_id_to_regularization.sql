-- Migration: Add batch_id to attendance_regularization
-- Allows multi-day requests (e.g. 60-day On-Duty) to be grouped under a single batch_id
-- for 1-click batch approval while retaining daily records for shiftwise attendance procedures.

ALTER TABLE attendance_regularization 
ADD COLUMN batch_id VARCHAR(64) DEFAULT NULL AFTER id,
ADD KEY idx_ar_batch_id (batch_id);

-- Backfill legacy records so every existing record has a unique batch_id
UPDATE attendance_regularization 
SET batch_id = CONCAT('legacy-', id) 
WHERE batch_id IS NULL;
