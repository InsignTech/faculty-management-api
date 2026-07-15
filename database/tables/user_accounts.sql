DROP TABLE IF EXISTS `user_accounts`;

CREATE TABLE `user_accounts` (
  `user_accounts_id` int NOT NULL AUTO_INCREMENT,
  `user_display_name` varchar(45) DEFAULT NULL,
  `user_password` varchar(5000) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `employee_id` int DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `active` tinyint DEFAULT NULL,
  `role_id` int DEFAULT NULL,
  `otp` int DEFAULT NULL,
  `otp_generated_on` datetime DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(100) DEFAULT NULL,
  `last_login_on` datetime DEFAULT NULL,
  PRIMARY KEY (`user_accounts_id`),
  KEY `idx_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=76 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
