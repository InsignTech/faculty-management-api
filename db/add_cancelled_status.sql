USE `staffdesk`;

-- Add 'Cancelled' to leave_requests status ENUM
ALTER TABLE leave_requests MODIFY COLUMN status ENUM('Pending', 'Approved', 'Rejected', 'Cancelled') DEFAULT 'Pending';

-- Update cancelLeaveRequest logic in the controller is also needed.
