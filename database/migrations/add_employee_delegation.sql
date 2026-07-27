-- Migration to add On-Behalf-Of Delegation support

-- 1. Create employee_delegation mapping table
CREATE TABLE IF NOT EXISTS `employee_delegation` (
  `delegation_id` int NOT NULL AUTO_INCREMENT,
  `delegate_employee_id` int NOT NULL,
  `target_employee_id` int NOT NULL,
  `is_active` tinyint DEFAULT '1',
  `created_by` varchar(50) DEFAULT NULL,
  `created_on` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`delegation_id`),
  UNIQUE KEY `uq_delegate_target` (`delegate_employee_id`,`target_employee_id`),
  CONSTRAINT `fk_delegate_employee` FOREIGN KEY (`delegate_employee_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_target_employee` FOREIGN KEY (`target_employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2. Add columns to leave_requests for auditing proxy requests
ALTER TABLE `leave_requests` 
  ADD COLUMN `applied_by_id` INT NULL,
  ADD COLUMN `is_proxy` TINYINT DEFAULT 0,
  ADD CONSTRAINT `fk_leave_applied_by` FOREIGN KEY (`applied_by_id`) REFERENCES `employee` (`employee_id`);

-- 3. Add columns to attendance_regularization for auditing proxy requests
ALTER TABLE `attendance_regularization` 
  ADD COLUMN `applied_by_id` INT NULL,
  ADD COLUMN `is_proxy` TINYINT DEFAULT 0,
  ADD CONSTRAINT `fk_reg_applied_by` FOREIGN KEY (`applied_by_id`) REFERENCES `employee` (`employee_id`);
