DROP TABLE IF EXISTS `employee_personal_ids`;

CREATE TABLE `employee_personal_ids` (
  `employee_id` int NOT NULL,
  `aadhar_number` varchar(20) DEFAULT NULL,
  `aadhar_file` varchar(255) DEFAULT NULL,
  `pan_number` varchar(20) DEFAULT NULL,
  `pan_file` varchar(255) DEFAULT NULL,
  `passport_number` varchar(50) DEFAULT NULL,
  `passport_file` varchar(255) DEFAULT NULL,
  `voter_id_number` varchar(50) DEFAULT NULL,
  `voter_id_file` varchar(255) DEFAULT NULL,
  `driving_licence_number` varchar(50) DEFAULT NULL,
  `driving_licence_file` varchar(255) DEFAULT NULL,
  `uan_number` varchar(50) DEFAULT NULL,
  `uan_file` varchar(255) DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`employee_id`),
  CONSTRAINT `employee_personal_ids_ibfk_1` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
