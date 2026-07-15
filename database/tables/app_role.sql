DROP TABLE IF EXISTS `app_role`;

CREATE TABLE `app_role` (
  `role_id` int NOT NULL AUTO_INCREMENT,
  `role` varchar(45) DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  `role_privilage` longtext,
  PRIMARY KEY (`role_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
