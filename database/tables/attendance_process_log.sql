DROP TABLE IF EXISTS `attendance_process_log`;

CREATE TABLE `attendance_process_log` (
  `process_id` int NOT NULL AUTO_INCREMENT,
  `process_date` date NOT NULL,
  `status` enum('Success','Failed','Skipped') NOT NULL,
  `message` varchar(255) DEFAULT NULL,
  `processed_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`process_id`),
  UNIQUE KEY `idx_process_date` (`process_date`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
