DROP TABLE IF EXISTS `holiday_master`;

CREATE TABLE `holiday_master` (
  `holiday_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL DEFAULT '-1' COMMENT '-1 = applies to all employees, specific ID = individual employee',
  `holiday_name` varchar(100) NOT NULL,
  `holiday_start_date` date NOT NULL,
  `holiday_end_date` date NOT NULL,
  `holiday_type` enum('WeekEnd','Public Holiday','Exceptional Holiday','Vacation') NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`holiday_id`),
  UNIQUE KEY `uq_holiday_employee_date` (`employee_id`,`holiday_start_date`,`holiday_end_date`,`holiday_type`),
  KEY `idx_holiday_date_range` (`holiday_start_date`,`holiday_end_date`),
  KEY `idx_holiday_employee` (`employee_id`),
  KEY `idx_holiday_type` (`holiday_type`),
  KEY `idx_holiday_lookup` (`employee_id`,`holiday_start_date`,`holiday_end_date`,`is_active`),
  CONSTRAINT `chk_holiday_dates` CHECK ((`holiday_end_date` >= `holiday_start_date`))
) ENGINE=InnoDB AUTO_INCREMENT=5463 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
