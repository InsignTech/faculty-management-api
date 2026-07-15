DROP TABLE IF EXISTS `attendance`;

CREATE TABLE `attendance` (
  `attendance_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `date` date NOT NULL,
  `status` enum('Absent','Present') NOT NULL,
  `punch_type` enum('Onduty','Manual','Biometric') NOT NULL,
  `type` enum('PunchIn','PunchOut') NOT NULL,
  `shift_type` enum('First Half','Second Half','Full Day') NOT NULL,
  `punch_time` time NOT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`attendance_id`),
  UNIQUE KEY `idx_emp_date_type` (`employee_id`,`date`,`type`),
  CONSTRAINT `fk_attendance_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
