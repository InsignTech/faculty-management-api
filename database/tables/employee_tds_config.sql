DROP TABLE IF EXISTS `employee_tds_config`;

CREATE TABLE `employee_tds_config` (
  `tds_config_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `financial_year` varchar(9) NOT NULL,
  `tax_regime` enum('old','new') NOT NULL DEFAULT 'new',
  `taxable_components` varchar(300) NOT NULL DEFAULT 'basic_pay,hra,educational_allowance,special_allowance,naac_allowance',
  `tds_override_amount` decimal(15,2) DEFAULT NULL,
  `tds_override_reason` varchar(255) DEFAULT NULL,
  `declared_80c` decimal(15,2) NOT NULL DEFAULT '0.00',
  `declared_80d` decimal(15,2) NOT NULL DEFAULT '0.00',
  `declared_hra_exempt` decimal(15,2) NOT NULL DEFAULT '0.00',
  `declared_other` decimal(15,2) NOT NULL DEFAULT '0.00',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `modified_on` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`tds_config_id`),
  UNIQUE KEY `uq_tds` (`employee_id`,`financial_year`),
  CONSTRAINT `fk_tds_emp` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
