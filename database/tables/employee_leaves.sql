DROP TABLE IF EXISTS `employee_leaves`;

CREATE TABLE `employee_leaves` (
  `id` int NOT NULL AUTO_INCREMENT,
  `emp_id` int NOT NULL,
  `leave_type` varchar(50) NOT NULL,
  `month_year` varchar(7) NOT NULL,
  `opening_leave` decimal(10,2) DEFAULT '0.00',
  `credited_count` decimal(10,2) DEFAULT '0.00',
  `leaves_taken` decimal(10,2) DEFAULT '0.00',
  `total_leaves` decimal(10,2) GENERATED ALWAYS AS ((`opening_leave` + `credited_count`)) STORED,
  `balance_leave` decimal(10,2) GENERATED ALWAYS AS (((`opening_leave` + `credited_count`) - `leaves_taken`)) STORED,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_emp_leave_month` (`emp_id`,`leave_type`,`month_year`),
  CONSTRAINT `fk_emp_leaves_employee` FOREIGN KEY (`emp_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB AUTO_INCREMENT=608 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
