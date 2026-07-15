DROP TABLE IF EXISTS `employee_approver_configs`;

CREATE TABLE `employee_approver_configs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `request_type` enum('LEAVE','REGULARISATION','ONDUTY') NOT NULL,
  `approver_1_id` int NOT NULL,
  `approver_2_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_emp_req_type` (`employee_id`,`request_type`),
  KEY `fk_eac_approver1` (`approver_1_id`),
  KEY `fk_eac_approver2` (`approver_2_id`),
  CONSTRAINT `fk_eac_approver1` FOREIGN KEY (`approver_1_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_eac_approver2` FOREIGN KEY (`approver_2_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_eac_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=373 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
