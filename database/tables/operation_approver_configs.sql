CREATE TABLE IF NOT EXISTS `operation_approver_configs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `request_type` VARCHAR(50) NOT NULL UNIQUE,
  `approver_1_id` INT NOT NULL,
  `approver_2_id` INT DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_oac_approver1` FOREIGN KEY (`approver_1_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_oac_approver2` FOREIGN KEY (`approver_2_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
