DROP TABLE IF EXISTS `leave_policy`;

CREATE TABLE `leave_policy` (
  `leave_policy_id` int NOT NULL AUTO_INCREMENT,
  `policy_name` varchar(245) DEFAULT NULL,
  `policy_value` longtext,
  `active` tinyint DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL,
  PRIMARY KEY (`leave_policy_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
