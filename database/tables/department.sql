DROP TABLE IF EXISTS `department`;

CREATE TABLE `department` (
  `department_id` int NOT NULL AUTO_INCREMENT,
  `departmentname` varchar(45) NOT NULL,
  PRIMARY KEY (`department_id`),
  UNIQUE KEY `departmentname` (`departmentname`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
