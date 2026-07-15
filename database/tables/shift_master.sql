DROP TABLE IF EXISTS `shift_master`;

CREATE TABLE `shift_master` (
  `shift_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `shift_type` enum('FullDay','FirstHalf','SecondHalf') NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `start_grace_mins` int NOT NULL DEFAULT '0',
  `end_grace_mins` int NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` varchar(50) NOT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`shift_id`),
  KEY `idx_shift_lookup` (`employee_id`,`start_date`,`end_date`,`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
