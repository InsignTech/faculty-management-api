DROP TABLE IF EXISTS `exceptional_days`;

CREATE TABLE `exceptional_days` (
  `exceptional_id` int NOT NULL AUTO_INCREMENT,
  `holiday_date` date NOT NULL,
  `description` varchar(255) NOT NULL,
  `is_active` tinyint DEFAULT '1',
  `added_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`exceptional_id`),
  UNIQUE KEY `idx_date_exceptional` (`holiday_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
