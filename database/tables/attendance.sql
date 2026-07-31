DROP TABLE IF EXISTS `attendance`;

CREATE TABLE `attendance` (
  `attendance_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int DEFAULT NULL,
  `date` date DEFAULT NULL,
  `first_in_time` time DEFAULT NULL,
  `last_out_time` time DEFAULT NULL,
  `worked_mins` int DEFAULT '0',
  `shift_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT NULL,
  `status` enum('Present','Absent','WeekEnd','Public Holiday','Exceptional Holiday','Vacation','Leave', 'Regularized', 'OnDuty') DEFAULT NULL,
  `is_late` tinyint DEFAULT '0',
  `late_minutes` int DEFAULT '0',
  `is_early_leaving` tinyint DEFAULT '0',
  `early_minutes` int DEFAULT '0',
  `overtime_minutes` int DEFAULT '0',
  `deduction_days` decimal(3,2) DEFAULT '0.00',
  `is_worked_on_holiday` tinyint DEFAULT '0',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`attendance_id`),
  UNIQUE KEY `uk_emp_date` (`employee_id`,`date`,`shift_type`)
) ENGINE=InnoDB AUTO_INCREMENT=6858 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
