DROP TABLE IF EXISTS `payroll_approval_log`;

CREATE TABLE `payroll_approval_log` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `disbursement_id` int NOT NULL,
  `period_id` int NOT NULL,
  `action` enum('prepared','submitted','verified','approved','rejected','paid','edited') NOT NULL,
  `action_by` int NOT NULL,
  `action_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `remarks` varchar(500) DEFAULT NULL,
  `previous_status` varchar(30) DEFAULT NULL,
  `new_status` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`log_id`),
  KEY `fk_log_disb` (`disbursement_id`),
  KEY `fk_log_period` (`period_id`),
  KEY `fk_log_actor` (`action_by`),
  CONSTRAINT `fk_log_actor` FOREIGN KEY (`action_by`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_log_disb` FOREIGN KEY (`disbursement_id`) REFERENCES `salary_disbursement` (`disbursement_id`),
  CONSTRAINT `fk_log_period` FOREIGN KEY (`period_id`) REFERENCES `payroll_period` (`period_id`)
) ENGINE=InnoDB AUTO_INCREMENT=709 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
