DROP TABLE IF EXISTS `employee_loan`;

CREATE TABLE `employee_loan` (
  `loan_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `loan_type` enum('salary_advance','personal_loan','festival_advance','other') NOT NULL,
  `loan_amount` decimal(15,2) NOT NULL,
  `reason` text,
  `approved_on` date DEFAULT NULL,
  `approved_by` int DEFAULT NULL,
  `status` enum('pending','approved','active','closed','rejected') NOT NULL DEFAULT 'pending',
  `monthly_deduction` decimal(15,2) DEFAULT NULL,
  `deduction_start_month` tinyint NOT NULL,
  `deduction_start_year` smallint NOT NULL,
  `total_paid_amount` decimal(15,2) NOT NULL DEFAULT '0.00',
  `balance_amount` decimal(15,2) GENERATED ALWAYS AS ((`loan_amount` - `total_paid_amount`)) STORED,
  `remarks` varchar(255) DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `modified_on` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`loan_id`),
  KEY `fk_loan_emp` (`employee_id`),
  KEY `fk_loan_approved_by` (`approved_by`),
  CONSTRAINT `fk_loan_approved_by` FOREIGN KEY (`approved_by`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_loan_emp` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
