DROP TABLE IF EXISTS `leave_policy_role`;

CREATE TABLE `leave_policy_role` (
  `leave_policy_role_id` int NOT NULL AUTO_INCREMENT,
  `leave_policy_id` int NOT NULL,
  `role_id` int NOT NULL,
  `policy_value` longtext NOT NULL,
  `active` tinyint DEFAULT '1',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`leave_policy_role_id`),
  UNIQUE KEY `idx_role_policy` (`role_id`,`leave_policy_id`),
  KEY `leave_policy_id` (`leave_policy_id`),
  CONSTRAINT `leave_policy_role_ibfk_1` FOREIGN KEY (`leave_policy_id`) REFERENCES `leave_policy` (`leave_policy_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
