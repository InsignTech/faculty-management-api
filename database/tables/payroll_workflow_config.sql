DROP TABLE IF EXISTS `payroll_workflow_config`;

CREATE TABLE `payroll_workflow_config` (
  `level_id` int NOT NULL AUTO_INCREMENT,
  `level_number` int DEFAULT NULL,
  `level_name` varchar(100) DEFAULT NULL,
  `assigned_to_user_id` int DEFAULT NULL,
  `assigned_to_role` varchar(50) DEFAULT NULL,
  `is_active` tinyint DEFAULT '1',
  PRIMARY KEY (`level_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
