DROP TABLE IF EXISTS `attendance_punches_detail`;

CREATE TABLE `attendance_punches_detail` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `employee_code` varchar(45) DEFAULT NULL,
  `punch_time` datetime DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `processed_flag` int DEFAULT '0',
  PRIMARY KEY (`log_id`),
  UNIQUE KEY `idx_emp_punch` (`employee_code`,`punch_time`)
) ENGINE=InnoDB AUTO_INCREMENT=111 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
