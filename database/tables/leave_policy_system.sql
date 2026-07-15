DROP TABLE IF EXISTS `leave_policy_system`;

CREATE TABLE `leave_policy_system` (
  `leave_policy_system_id` int NOT NULL AUTO_INCREMENT,
  `leave_policy_id` int NOT NULL,
  `policy_value` longtext NOT NULL,
  `active` tinyint DEFAULT '1',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  `policy_year` int NOT NULL,
  PRIMARY KEY (`leave_policy_system_id`),
  KEY `leave_policy_id` (`leave_policy_id`),
  CONSTRAINT `leave_policy_system_ibfk_1` FOREIGN KEY (`leave_policy_id`) REFERENCES `leave_policy` (`leave_policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
