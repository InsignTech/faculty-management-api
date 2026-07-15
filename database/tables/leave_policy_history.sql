DROP TABLE IF EXISTS `leave_policy_history`;

CREATE TABLE `leave_policy_history` (
  `id` int NOT NULL AUTO_INCREMENT,
  `leave_policy_id` int NOT NULL,
  `policy_name` varchar(255) DEFAULT NULL,
  `policy_value` json DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `changed_by` varchar(100) DEFAULT NULL,
  `changed_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `change_type` enum('Created','Updated','Deleted','Activated') DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
