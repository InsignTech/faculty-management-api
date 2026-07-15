DROP TABLE IF EXISTS `designation`;

CREATE TABLE `designation` (
  `designation_id` int NOT NULL AUTO_INCREMENT,
  `designation` varchar(45) DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`designation_id`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
