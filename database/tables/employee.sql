DROP TABLE IF EXISTS `employee`;

CREATE TABLE `employee` (
  `employee_id` int NOT NULL AUTO_INCREMENT,
  `organization_id` int DEFAULT NULL,
  `employee_code` varchar(45) DEFAULT NULL,
  `employee_name` varchar(200) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `profile_picture` varchar(255) DEFAULT NULL,
  `role_id` int DEFAULT NULL,
  `designation_id` int DEFAULT NULL,

  `employee_type` enum(
    'Permanent',
    'Probation',
    'Contract',
    'Temporary',
    'Intern',
    'Trainee',
    'Consultant',
    'DailyWage',
    'Apprentice',
    'Outsourced'
  ) DEFAULT NULL,

  `employment_status` enum(
    'Active',
    'ProbationCompleted',
    'ContractCompleted',
    'Resigned',
    'Terminated',
    'Retired',
    'OnHold',
    'Absconded'
  ) NOT NULL DEFAULT 'Active',

  `status_effective_date` date DEFAULT NULL,

  `remarks` varchar(500) DEFAULT NULL,

  `reporting_manager_id` int DEFAULT NULL,
  `joining_date` date DEFAULT NULL,
  `active` tinyint DEFAULT NULL,

  `active_email` varchar(255)
  GENERATED ALWAYS AS (
    CASE
      WHEN `active` = 1 THEN `email`
      ELSE NULL
    END
  ) STORED,

  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  `modified_on` datetime DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  `department_id` int DEFAULT NULL,
  `basic_pay` decimal(15,2) DEFAULT '0.00',
  `title` varchar(20) DEFAULT NULL,
  `gender` enum('Male','Female','Other') DEFAULT NULL,
  `dob` date DEFAULT NULL,
  `marital_status` varchar(20) DEFAULT NULL,
  `nationality` varchar(50) DEFAULT NULL,
  `blood_group` varchar(5) DEFAULT NULL,
  `place_of_birth` varchar(100) DEFAULT NULL,
  `state_of_birth` varchar(100) DEFAULT NULL,
  `religion` varchar(50) DEFAULT NULL,
  `identification_mark` varchar(255) DEFAULT NULL,
  `mother_tongue` varchar(50) DEFAULT NULL,
  `educational_qualification` varchar(255) DEFAULT NULL,
  `additional_qualification` varchar(255) DEFAULT NULL,
  `present_address` text,
  `permanent_address` text,
  `contact_number` varchar(20) DEFAULT NULL,
  `alternative_contact_number` varchar(20) DEFAULT NULL,

  PRIMARY KEY (`employee_id`),

  UNIQUE KEY `idx_employee_code_unique` (`employee_code`),

  UNIQUE KEY `uq_active_email` (`active_email`)

) ENGINE=InnoDB
  AUTO_INCREMENT=1007
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci
  COMMENT='';