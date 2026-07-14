DROP TABLE IF EXISTS `leave_policy_employee`;

CREATE TABLE `leave_policy_employee` (
  `leave_policy_employee_id` int NOT NULL AUTO_INCREMENT,
  `leave_policy_id` int DEFAULT NULL,
  `employee_id` int DEFAULT NULL,
  `policy_value` longtext,
  `active` tinyint DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`leave_policy_employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
