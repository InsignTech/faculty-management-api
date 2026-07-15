DROP TABLE IF EXISTS `app_role_privilege`;

CREATE TABLE `app_role_privilege` (
  `app_role_privilege_id` int NOT NULL AUTO_INCREMENT,
  `role_id` int DEFAULT NULL,
  `settings_id` int DEFAULT NULL,
  `app_privilege_value` json DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`app_role_privilege_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
