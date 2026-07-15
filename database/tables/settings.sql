DROP TABLE IF EXISTS `settings`;

CREATE TABLE `settings` (
  `settings_id` int NOT NULL AUTO_INCREMENT,
  `settings_key` varchar(150) DEFAULT NULL,
  `settings_value` longtext,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`settings_id`),
  UNIQUE KEY `settings_key_UNIQUE` (`settings_key`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
