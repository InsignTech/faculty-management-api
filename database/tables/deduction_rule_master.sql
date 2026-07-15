DROP TABLE IF EXISTS `deduction_rule_master`;

CREATE TABLE `deduction_rule_master` (
  `rule_id` int NOT NULL AUTO_INCREMENT,
  `organization_id` int NOT NULL,
  `deduction_code` varchar(30) NOT NULL,
  `deduction_name` varchar(100) NOT NULL,
  `calc_type` enum('percentage','fixed','slab','manual','loan_emi') NOT NULL,
  `rate` decimal(8,4) DEFAULT NULL,
  `calc_basis` varchar(200) DEFAULT NULL,
  `eligibility_ceiling` decimal(15,2) DEFAULT NULL,
  `wage_ceiling` decimal(15,2) DEFAULT NULL,
  `fixed_amount` decimal(15,2) DEFAULT NULL,
  `is_statutory` tinyint(1) NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `display_order` tinyint NOT NULL DEFAULT '0',
  `notes` varchar(500) DEFAULT NULL,
  `applicable_months` varchar(100) DEFAULT NULL,
  `projection_multiplier` int DEFAULT '1',
  PRIMARY KEY (`rule_id`),
  UNIQUE KEY `uq_rule` (`organization_id`,`deduction_code`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
