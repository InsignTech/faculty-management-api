DROP TABLE IF EXISTS `payroll_period`;

CREATE TABLE `payroll_period` (
  `period_id` int NOT NULL AUTO_INCREMENT,
  `organization_id` int NOT NULL,
  `month` tinyint NOT NULL,
  `year` smallint NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `status` enum('draft','processing','completed','locked') DEFAULT 'draft',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`period_id`),
  UNIQUE KEY `uq_period` (`organization_id`,`month`,`year`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
