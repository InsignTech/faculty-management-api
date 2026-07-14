DROP TABLE IF EXISTS `attendance_detail`;

CREATE TABLE `attendance_detail` (
  `detail_id` int NOT NULL AUTO_INCREMENT,
  `attendance_id` int DEFAULT NULL,
  `employee_id` varchar(45) DEFAULT NULL,
  `punch_time` datetime DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`detail_id`),
  UNIQUE KEY `idx_emp_punch` (`employee_id`,`punch_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
