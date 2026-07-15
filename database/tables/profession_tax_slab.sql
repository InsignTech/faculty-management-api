DROP TABLE IF EXISTS `profession_tax_slab`;

CREATE TABLE `profession_tax_slab` (
  `slab_id` int NOT NULL AUTO_INCREMENT,
  `organization_id` int NOT NULL,
  `state_code` varchar(10) NOT NULL DEFAULT 'KL',
  `min_salary` decimal(15,2) NOT NULL,
  `max_salary` decimal(15,2) DEFAULT NULL,
  `monthly_tax` decimal(10,2) NOT NULL,
  `effective_from` date NOT NULL,
  `effective_to` date DEFAULT NULL,
  PRIMARY KEY (`slab_id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
