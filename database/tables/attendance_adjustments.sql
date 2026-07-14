DROP TABLE IF EXISTS `attendance_adjustments`;

CREATE TABLE `attendance_adjustments` (
  `adjustment_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `type` enum('Regularization','OnDuty') NOT NULL,
  `requested_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `date` date NOT NULL,
  `punch_time` time NOT NULL,
  `remarks` text,
  `status` enum('Pending','Approved','Rejected') DEFAULT 'Pending',
  `approved_by_id` int DEFAULT NULL,
  `approved_on` datetime DEFAULT NULL,
  `attachment_path` varchar(512) DEFAULT NULL,
  PRIMARY KEY (`adjustment_id`),
  KEY `fk_adjustment_employee` (`employee_id`),
  CONSTRAINT `fk_adjustment_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
