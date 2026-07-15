DROP TABLE IF EXISTS `salary_structure`;

CREATE TABLE `salary_structure` (
  `structure_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `basic_pay` decimal(15,2) NOT NULL DEFAULT '0.00',
  `hra` decimal(15,2) NOT NULL DEFAULT '0.00',
  `educational_allowance` decimal(15,2) NOT NULL DEFAULT '0.00',
  `special_allowance` decimal(15,2) NOT NULL DEFAULT '0.00',
  `naac_allowance` decimal(15,2) NOT NULL DEFAULT '0.00',
  `gross_salary` decimal(15,2) GENERATED ALWAYS AS (((((`basic_pay` + `hra`) + `educational_allowance`) + `special_allowance`) + `naac_allowance`)) STORED,
  `effective_from` date NOT NULL,
  `effective_to` date DEFAULT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`structure_id`),
  KEY `fk_ss_emp` (`employee_id`),
  CONSTRAINT `fk_ss_emp` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB AUTO_INCREMENT=83 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
