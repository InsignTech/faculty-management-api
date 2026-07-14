DROP TABLE IF EXISTS `employee_bank_account`;

CREATE TABLE `employee_bank_account` (
  `account_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `bank_name` varchar(100) NOT NULL,
  `branch_name` varchar(100) NOT NULL,
  `account_number` varchar(30) NOT NULL,
  `ifsc_code` varchar(11) NOT NULL,
  `account_type` enum('savings','current','salary') NOT NULL DEFAULT 'savings',
  `is_primary` tinyint(1) NOT NULL DEFAULT '1',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `modified_on` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`),
  KEY `fk_bank_emp` (`employee_id`),
  CONSTRAINT `fk_bank_emp` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
