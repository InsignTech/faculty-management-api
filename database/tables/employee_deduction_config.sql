DROP TABLE IF EXISTS `employee_deduction_config`;

CREATE TABLE `employee_deduction_config` (
  `config_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `rule_id` int NOT NULL,
  `is_applicable` tinyint(1) NOT NULL DEFAULT '1',
  `override_amount` decimal(15,2) DEFAULT NULL,
  `effective_from` date NOT NULL,
  `effective_to` date DEFAULT NULL,
  PRIMARY KEY (`config_id`),
  UNIQUE KEY `uq_edc` (`employee_id`,`rule_id`,`effective_from`),
  KEY `fk_edc_rule` (`rule_id`),
  CONSTRAINT `fk_edc_emp` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_edc_rule` FOREIGN KEY (`rule_id`) REFERENCES `deduction_rule_master` (`rule_id`)
) ENGINE=InnoDB AUTO_INCREMENT=72 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
