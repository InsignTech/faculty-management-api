DROP TABLE IF EXISTS `attendance_daily`;

CREATE TABLE `attendance_daily` (
  `attendance_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int DEFAULT NULL,
  `date` date DEFAULT NULL,
  `first_in_time` time DEFAULT NULL,
  `last_out_time` time DEFAULT NULL,
  `worked_mins` int DEFAULT '0',
  `shift_type` enum('FullDay','FirstHalf','SecondHalf','Absent') DEFAULT NULL,
  `status` enum('Present','Absent','WeekEnd','Public Holiday','Exceptional Holiday','Vacation','Leave') DEFAULT NULL,
  `is_late` tinyint DEFAULT '0',
  `late_minutes` int DEFAULT '0',
  `is_early_leaving` tinyint DEFAULT '0',
  `early_minutes` int DEFAULT '0',
  `overtime_minutes` int DEFAULT '0',
  `deduction_days` decimal(3,2) DEFAULT '0.00',
  `is_worked_on_holiday` tinyint DEFAULT '0',
  `onduty_shift_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT NULL,
  `is_leave` tinyint DEFAULT '0',
  `leave_shift_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT NULL,
  `regularization_shift_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `is_leave_type` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`attendance_id`),
  UNIQUE KEY `uk_emp_date` (`employee_id`,`date`)
) ENGINE=InnoDB AUTO_INCREMENT=5375 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
