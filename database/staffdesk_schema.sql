-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: staffdesk
-- ------------------------------------------------------
-- Server version	8.0.46-0ubuntu0.24.04.3

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `app_role`
--

DROP TABLE IF EXISTS `app_role`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `app_role` (
  `role_id` int NOT NULL AUTO_INCREMENT,
  `role` varchar(45) DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  `role_privilage` longtext,
  PRIMARY KEY (`role_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `app_role_privilege`
--

DROP TABLE IF EXISTS `app_role_privilege`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `app_role_privilege` (
  `app_role_privilege_id` int NOT NULL AUTO_INCREMENT,
  `role_id` int DEFAULT NULL,
  `settings_id` int DEFAULT NULL,
  `app_privilege_value` json DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`app_role_privilege_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance`
--

DROP TABLE IF EXISTS `attendance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance` (
  `attendance_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `date` date NOT NULL,
  `status` enum('Absent','Present') NOT NULL,
  `punch_type` enum('Onduty','Manual','Biometric') NOT NULL,
  `type` enum('PunchIn','PunchOut') NOT NULL,
  `shift_type` enum('First Half','Second Half','Full Day') NOT NULL,
  `punch_time` time NOT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`attendance_id`),
  UNIQUE KEY `idx_emp_date_type` (`employee_id`,`date`,`type`),
  CONSTRAINT `fk_attendance_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_adjustments`
--

DROP TABLE IF EXISTS `attendance_adjustments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_daily`
--

DROP TABLE IF EXISTS `attendance_daily`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_daily` (
  `attendance_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int DEFAULT NULL,
  `date` date DEFAULT NULL,
  `first_in_time` time DEFAULT NULL,
  `last_out_time` time DEFAULT NULL,
  `worked_mins` int DEFAULT '0',
  `shift_type` enum('FullDay','FirstHalf','SecondHalf','Absent') DEFAULT NULL,
  `status` enum('Present','Absent','WeekEnd','Public Holiday','Exceptional Holiday','Vacation','Leave') DEFAULT NULL,
  `is_late` tinyint DEFAULT '0',
  `late_minutes` int DEFAULT '0',
  `is_early_leaving` tinyint DEFAULT '0',
  `early_minutes` int DEFAULT '0',
  `overtime_minutes` int DEFAULT '0',
  `deduction_days` decimal(3,2) DEFAULT '0.00',
  `is_worked_on_holiday` tinyint DEFAULT '0',
  `onduty_shift_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT NULL,
  `is_leave` tinyint DEFAULT '0',
  `leave_shift_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT NULL,
  `regularization_shift_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `is_leave_type` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`attendance_id`),
  UNIQUE KEY `uk_emp_date` (`employee_id`,`date`)
) ENGINE=InnoDB AUTO_INCREMENT=5375 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_detail`
--

DROP TABLE IF EXISTS `attendance_detail`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_detail` (
  `detail_id` int NOT NULL AUTO_INCREMENT,
  `attendance_id` int DEFAULT NULL,
  `employee_id` varchar(45) DEFAULT NULL,
  `punch_time` datetime DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`detail_id`),
  UNIQUE KEY `idx_emp_punch` (`employee_id`,`punch_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_detail_log`
--

DROP TABLE IF EXISTS `attendance_detail_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_detail_log` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `employee_code` varchar(45) DEFAULT NULL,
  `punch_time` datetime DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `processed_flag` int DEFAULT '0',
  PRIMARY KEY (`log_id`),
  UNIQUE KEY `idx_emp_punch` (`employee_code`,`punch_time`),
  KEY `idx_att_log` (`employee_code`,`punch_time`),
  KEY `idx_att_log_empcode_time` (`employee_code`,`punch_time`)
) ENGINE=InnoDB AUTO_INCREMENT=3422 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_invalid_log`
--

DROP TABLE IF EXISTS `attendance_invalid_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_invalid_log` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` varchar(45) DEFAULT NULL,
  `punch_time` datetime DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_process_log`
--

DROP TABLE IF EXISTS `attendance_process_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_process_log` (
  `process_id` int NOT NULL AUTO_INCREMENT,
  `process_date` date NOT NULL,
  `status` enum('Success','Failed','Skipped') NOT NULL,
  `message` varchar(255) DEFAULT NULL,
  `processed_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`process_id`),
  UNIQUE KEY `idx_process_date` (`process_date`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_punches_detail`
--

DROP TABLE IF EXISTS `attendance_punches_detail`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_punches_detail` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `employee_code` varchar(45) DEFAULT NULL,
  `punch_time` datetime DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `processed_flag` int DEFAULT '0',
  PRIMARY KEY (`log_id`),
  UNIQUE KEY `idx_emp_punch` (`employee_code`,`punch_time`)
) ENGINE=InnoDB AUTO_INCREMENT=111 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_regularization`
--

DROP TABLE IF EXISTS `attendance_regularization`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_regularization` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int DEFAULT NULL,
  `date` date DEFAULT NULL,
  `requested_in_time` time DEFAULT NULL,
  `requested_out_time` time DEFAULT NULL,
  `request_type` enum('Regularization','OnDuty') DEFAULT NULL,
  `regularization_shift_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `status` enum('Pending','Approved','Rejected') DEFAULT NULL,
  `created_on` datetime DEFAULT NULL,
  `approved_by` int DEFAULT NULL,
  `approved_on` datetime DEFAULT NULL,
  `substitute_employee_id` int DEFAULT NULL,
  `approver_1_id` int DEFAULT NULL,
  `approver_2_id` int DEFAULT NULL,
  `current_level` tinyint NOT NULL DEFAULT '1',
  `approver_1_remarks` text,
  `approver_1_action_on` datetime DEFAULT NULL,
  `approver_2_remarks` text,
  `approver_2_action_on` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_ar_substitute` (`substitute_employee_id`),
  KEY `fk_ar_approver1` (`approver_1_id`),
  KEY `fk_ar_approver2` (`approver_2_id`),
  CONSTRAINT `fk_ar_approver1` FOREIGN KEY (`approver_1_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_ar_approver2` FOREIGN KEY (`approver_2_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_ar_substitute` FOREIGN KEY (`substitute_employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB AUTO_INCREMENT=226 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_settings`
--

DROP TABLE IF EXISTS `attendance_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_settings` (
  `setting_id` int NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(100) NOT NULL,
  `setting_value` varchar(255) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`setting_id`),
  UNIQUE KEY `setting_key` (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendance_sync_logs`
--

DROP TABLE IF EXISTS `attendance_sync_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_sync_logs` (
  `sync_id` int NOT NULL AUTO_INCREMENT,
  `start_time` datetime NOT NULL,
  `end_time` datetime DEFAULT NULL,
  `total_records` int DEFAULT '0',
  `status` enum('Success','Failed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'Success',
  `error_message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `payload_preview` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`sync_id`)
) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deduction_rule_master`
--

DROP TABLE IF EXISTS `deduction_rule_master`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `department`
--

DROP TABLE IF EXISTS `department`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `department` (
  `department_id` int NOT NULL AUTO_INCREMENT,
  `departmentname` varchar(45) NOT NULL,
  PRIMARY KEY (`department_id`),
  UNIQUE KEY `departmentname` (`departmentname`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `designation`
--

DROP TABLE IF EXISTS `designation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `designation` (
  `designation_id` int NOT NULL AUTO_INCREMENT,
  `designation` varchar(45) DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`designation_id`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee`
--

DROP TABLE IF EXISTS `employee`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee` (
  `employee_id` int NOT NULL AUTO_INCREMENT,
  `organization_id` int DEFAULT NULL,
  `employee_code` varchar(45) DEFAULT NULL,
  `employee_name` varchar(200) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `profile_picture` varchar(255) DEFAULT NULL,
  `role_id` int DEFAULT NULL,
  `designation_id` int DEFAULT NULL,
  `employee_type` varchar(45) DEFAULT NULL,
  `reporting_manager_id` int DEFAULT NULL,
  `joining_date` date DEFAULT NULL,
  `active` tinyint DEFAULT NULL,
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
  UNIQUE KEY `idx_employee_email_unique` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=1007 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='	';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee_approver_configs`
--

DROP TABLE IF EXISTS `employee_approver_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_approver_configs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `request_type` enum('LEAVE','REGULARISATION','ONDUTY') NOT NULL,
  `approver_1_id` int NOT NULL,
  `approver_2_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_emp_req_type` (`employee_id`,`request_type`),
  KEY `fk_eac_approver1` (`approver_1_id`),
  KEY `fk_eac_approver2` (`approver_2_id`),
  CONSTRAINT `fk_eac_approver1` FOREIGN KEY (`approver_1_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_eac_approver2` FOREIGN KEY (`approver_2_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_eac_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=373 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee_bank_account`
--

DROP TABLE IF EXISTS `employee_bank_account`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_bank_account` (
  `account_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `bank_name` varchar(100) NOT NULL,
  `branch_name` varchar(100) NOT NULL,
  `account_number` varchar(30) NOT NULL,
  `ifsc_code` varchar(11) NOT NULL,
  `account_type` enum('savings','current','salary') NOT NULL DEFAULT 'savings',
  `is_primary` tinyint(1) NOT NULL DEFAULT '1',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `modified_on` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`),
  KEY `fk_bank_emp` (`employee_id`),
  CONSTRAINT `fk_bank_emp` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee_deduction_config`
--

DROP TABLE IF EXISTS `employee_deduction_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee_leaves`
--

DROP TABLE IF EXISTS `employee_leaves`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee_loan`
--

DROP TABLE IF EXISTS `employee_loan`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_loan` (
  `loan_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `loan_type` enum('salary_advance','personal_loan','festival_advance','other') NOT NULL,
  `loan_amount` decimal(15,2) NOT NULL,
  `reason` text,
  `approved_on` date DEFAULT NULL,
  `approved_by` int DEFAULT NULL,
  `status` enum('pending','approved','active','closed','rejected') NOT NULL DEFAULT 'pending',
  `monthly_deduction` decimal(15,2) DEFAULT NULL,
  `deduction_start_month` tinyint NOT NULL,
  `deduction_start_year` smallint NOT NULL,
  `total_paid_amount` decimal(15,2) NOT NULL DEFAULT '0.00',
  `balance_amount` decimal(15,2) GENERATED ALWAYS AS ((`loan_amount` - `total_paid_amount`)) STORED,
  `remarks` varchar(255) DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `modified_on` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`loan_id`),
  KEY `fk_loan_emp` (`employee_id`),
  KEY `fk_loan_approved_by` (`approved_by`),
  CONSTRAINT `fk_loan_approved_by` FOREIGN KEY (`approved_by`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_loan_emp` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee_personal_ids`
--

DROP TABLE IF EXISTS `employee_personal_ids`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_personal_ids` (
  `employee_id` int NOT NULL,
  `aadhar_number` varchar(20) DEFAULT NULL,
  `aadhar_file` varchar(255) DEFAULT NULL,
  `pan_number` varchar(20) DEFAULT NULL,
  `pan_file` varchar(255) DEFAULT NULL,
  `passport_number` varchar(50) DEFAULT NULL,
  `passport_file` varchar(255) DEFAULT NULL,
  `voter_id_number` varchar(50) DEFAULT NULL,
  `voter_id_file` varchar(255) DEFAULT NULL,
  `driving_licence_number` varchar(50) DEFAULT NULL,
  `driving_licence_file` varchar(255) DEFAULT NULL,
  `uan_number` varchar(50) DEFAULT NULL,
  `uan_file` varchar(255) DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`employee_id`),
  CONSTRAINT `employee_personal_ids_ibfk_1` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee_tds_config`
--

DROP TABLE IF EXISTS `employee_tds_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `exceptional_days`
--

DROP TABLE IF EXISTS `exceptional_days`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `exceptional_days` (
  `exceptional_id` int NOT NULL AUTO_INCREMENT,
  `holiday_date` date NOT NULL,
  `description` varchar(255) NOT NULL,
  `is_active` tinyint DEFAULT '1',
  `added_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`exceptional_id`),
  UNIQUE KEY `idx_date_exceptional` (`holiday_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `holiday_master`
--

DROP TABLE IF EXISTS `holiday_master`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `holiday_master` (
  `holiday_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL DEFAULT '-1' COMMENT '-1 = applies to all employees, specific ID = individual employee',
  `holiday_name` varchar(100) NOT NULL,
  `holiday_start_date` date NOT NULL,
  `holiday_end_date` date NOT NULL,
  `holiday_type` enum('WeekEnd','Public Holiday','Exceptional Holiday','Vacation') NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`holiday_id`),
  UNIQUE KEY `uq_holiday_employee_date` (`employee_id`,`holiday_start_date`,`holiday_end_date`,`holiday_type`),
  KEY `idx_holiday_date_range` (`holiday_start_date`,`holiday_end_date`),
  KEY `idx_holiday_employee` (`employee_id`),
  KEY `idx_holiday_type` (`holiday_type`),
  KEY `idx_holiday_lookup` (`employee_id`,`holiday_start_date`,`holiday_end_date`,`is_active`),
  CONSTRAINT `chk_holiday_dates` CHECK ((`holiday_end_date` >= `holiday_start_date`))
) ENGINE=InnoDB AUTO_INCREMENT=5463 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `leave_policy`
--

DROP TABLE IF EXISTS `leave_policy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_policy` (
  `leave_policy_id` int NOT NULL AUTO_INCREMENT,
  `policy_name` varchar(245) DEFAULT NULL,
  `policy_value` longtext,
  `active` tinyint DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL,
  PRIMARY KEY (`leave_policy_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `leave_policy_employee`
--

DROP TABLE IF EXISTS `leave_policy_employee`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_policy_employee` (
  `leave_policy_employee_id` int NOT NULL AUTO_INCREMENT,
  `leave_policy_id` int DEFAULT NULL,
  `employee_id` int DEFAULT NULL,
  `policy_value` longtext,
  `active` tinyint DEFAULT NULL,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`leave_policy_employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `leave_policy_history`
--

DROP TABLE IF EXISTS `leave_policy_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_policy_history` (
  `id` int NOT NULL AUTO_INCREMENT,
  `leave_policy_id` int NOT NULL,
  `policy_name` varchar(255) DEFAULT NULL,
  `policy_value` json DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `changed_by` varchar(100) DEFAULT NULL,
  `changed_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `change_type` enum('Created','Updated','Deleted','Activated') DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `leave_policy_role`
--

DROP TABLE IF EXISTS `leave_policy_role`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_policy_role` (
  `leave_policy_role_id` int NOT NULL AUTO_INCREMENT,
  `leave_policy_id` int NOT NULL,
  `role_id` int NOT NULL,
  `policy_value` longtext NOT NULL,
  `active` tinyint DEFAULT '1',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`leave_policy_role_id`),
  UNIQUE KEY `idx_role_policy` (`role_id`,`leave_policy_id`),
  KEY `leave_policy_id` (`leave_policy_id`),
  CONSTRAINT `leave_policy_role_ibfk_1` FOREIGN KEY (`leave_policy_id`) REFERENCES `leave_policy` (`leave_policy_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `leave_policy_system`
--

DROP TABLE IF EXISTS `leave_policy_system`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_policy_system` (
  `leave_policy_system_id` int NOT NULL AUTO_INCREMENT,
  `leave_policy_id` int NOT NULL,
  `policy_value` longtext NOT NULL,
  `active` tinyint DEFAULT '1',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  `policy_year` int NOT NULL,
  PRIMARY KEY (`leave_policy_system_id`),
  KEY `leave_policy_id` (`leave_policy_id`),
  CONSTRAINT `leave_policy_system_ibfk_1` FOREIGN KEY (`leave_policy_id`) REFERENCES `leave_policy` (`leave_policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `leave_requests`
--

DROP TABLE IF EXISTS `leave_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_requests` (
  `leave_request_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `leave_type` varchar(50) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `total_days` decimal(5,2) NOT NULL,
  `leave_half_type` enum('FullDay','FirstHalf','SecondHalf') DEFAULT 'FullDay',
  `reason` text,
  `status` enum('Pending','Approved','Rejected','Cancelled') DEFAULT 'Pending',
  `applied_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `approved_by_id` int DEFAULT NULL,
  `approved_on` datetime DEFAULT NULL,
  `rejection_reason` text,
  `attachment_path` varchar(512) DEFAULT NULL,
  `substitute_employee_id` int DEFAULT NULL,
  `approver_1_id` int DEFAULT NULL,
  `approver_2_id` int DEFAULT NULL,
  `current_level` tinyint NOT NULL DEFAULT '1',
  `approver_1_remarks` text,
  `approver_1_action_on` datetime DEFAULT NULL,
  `approver_2_remarks` text,
  `approver_2_action_on` datetime DEFAULT NULL,
  `is_paid` tinyint NOT NULL DEFAULT '1',
  PRIMARY KEY (`leave_request_id`),
  KEY `fk_leave_request_employee` (`employee_id`),
  KEY `fk_lr_substitute` (`substitute_employee_id`),
  KEY `fk_lr_approver1` (`approver_1_id`),
  KEY `fk_lr_approver2` (`approver_2_id`),
  CONSTRAINT `fk_leave_request_employee` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_lr_approver1` FOREIGN KEY (`approver_1_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_lr_approver2` FOREIGN KEY (`approver_2_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_lr_substitute` FOREIGN KEY (`substitute_employee_id`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB AUTO_INCREMENT=93 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payroll_approval_log`
--

DROP TABLE IF EXISTS `payroll_approval_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payroll_approval_log` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `disbursement_id` int NOT NULL,
  `period_id` int NOT NULL,
  `action` enum('prepared','submitted','verified','approved','rejected','paid','edited') NOT NULL,
  `action_by` int NOT NULL,
  `action_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `remarks` varchar(500) DEFAULT NULL,
  `previous_status` varchar(30) DEFAULT NULL,
  `new_status` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`log_id`),
  KEY `fk_log_disb` (`disbursement_id`),
  KEY `fk_log_period` (`period_id`),
  KEY `fk_log_actor` (`action_by`),
  CONSTRAINT `fk_log_actor` FOREIGN KEY (`action_by`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_log_disb` FOREIGN KEY (`disbursement_id`) REFERENCES `salary_disbursement` (`disbursement_id`),
  CONSTRAINT `fk_log_period` FOREIGN KEY (`period_id`) REFERENCES `payroll_period` (`period_id`)
) ENGINE=InnoDB AUTO_INCREMENT=709 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payroll_period`
--

DROP TABLE IF EXISTS `payroll_period`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payroll_period` (
  `period_id` int NOT NULL AUTO_INCREMENT,
  `organization_id` int NOT NULL,
  `month` tinyint NOT NULL,
  `year` smallint NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `status` enum('draft','processing','completed','locked') DEFAULT 'draft',
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`period_id`),
  UNIQUE KEY `uq_period` (`organization_id`,`month`,`year`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payroll_workflow_config`
--

DROP TABLE IF EXISTS `payroll_workflow_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payroll_workflow_config` (
  `level_id` int NOT NULL AUTO_INCREMENT,
  `level_number` int DEFAULT NULL,
  `level_name` varchar(100) DEFAULT NULL,
  `assigned_to_user_id` int DEFAULT NULL,
  `assigned_to_role` varchar(50) DEFAULT NULL,
  `is_active` tinyint DEFAULT '1',
  PRIMARY KEY (`level_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `profession_tax_slab`
--

DROP TABLE IF EXISTS `profession_tax_slab`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `salary_disbursement`
--

DROP TABLE IF EXISTS `salary_disbursement`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `salary_disbursement` (
  `disbursement_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `structure_id` int NOT NULL,
  `period_id` int NOT NULL,
  `basic_pay` decimal(15,2) NOT NULL,
  `hra` decimal(15,2) NOT NULL DEFAULT '0.00',
  `educational_allowance` decimal(15,2) NOT NULL DEFAULT '0.00',
  `special_allowance` decimal(15,2) NOT NULL DEFAULT '0.00',
  `naac_allowance` decimal(15,2) NOT NULL DEFAULT '0.00',
  `gross_salary` decimal(15,2) NOT NULL,
  `lop_days` decimal(5,2) NOT NULL DEFAULT '0.00',
  `payable_amount` decimal(15,2) NOT NULL,
  `deductions_json` json DEFAULT NULL,
  `total_deduction` decimal(15,2) NOT NULL DEFAULT '0.00',
  `net_salary` decimal(15,2) NOT NULL,
  `status` enum('draft','submitted','verified','approved','paid','rejected') NOT NULL DEFAULT 'draft',
  `prepared_by` int DEFAULT NULL,
  `prepared_on` datetime DEFAULT NULL,
  `verified_by` int DEFAULT NULL,
  `verified_on` datetime DEFAULT NULL,
  `verified_remarks` varchar(255) DEFAULT NULL,
  `approved_by` int DEFAULT NULL,
  `approved_on` datetime DEFAULT NULL,
  `approved_remarks` varchar(255) DEFAULT NULL,
  `rejected_by` int DEFAULT NULL,
  `rejected_on` datetime DEFAULT NULL,
  `rejected_remarks` varchar(255) DEFAULT NULL,
  `payment_date` date DEFAULT NULL,
  `remarks` varchar(255) DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`disbursement_id`),
  UNIQUE KEY `uq_disbursement_employee_period` (`employee_id`,`period_id`),
  KEY `fk_disb_struct` (`structure_id`),
  KEY `fk_disb_period` (`period_id`),
  KEY `fk_disb_prep` (`prepared_by`),
  KEY `fk_disb_veri` (`verified_by`),
  KEY `fk_disb_appr` (`approved_by`),
  CONSTRAINT `fk_disb_appr` FOREIGN KEY (`approved_by`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_disb_emp` FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_disb_period` FOREIGN KEY (`period_id`) REFERENCES `payroll_period` (`period_id`),
  CONSTRAINT `fk_disb_prep` FOREIGN KEY (`prepared_by`) REFERENCES `employee` (`employee_id`),
  CONSTRAINT `fk_disb_struct` FOREIGN KEY (`structure_id`) REFERENCES `salary_structure` (`structure_id`),
  CONSTRAINT `fk_disb_veri` FOREIGN KEY (`verified_by`) REFERENCES `employee` (`employee_id`)
) ENGINE=InnoDB AUTO_INCREMENT=709 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `salary_structure`
--

DROP TABLE IF EXISTS `salary_structure`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `settings`
--

DROP TABLE IF EXISTS `settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `settings` (
  `settings_id` int NOT NULL AUTO_INCREMENT,
  `settings_key` varchar(150) DEFAULT NULL,
  `settings_value` longtext,
  `created_on` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`settings_id`),
  UNIQUE KEY `settings_key_UNIQUE` (`settings_key`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `shift_master`
--

DROP TABLE IF EXISTS `shift_master`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `shift_master` (
  `shift_id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `shift_type` enum('FullDay','FirstHalf','SecondHalf') NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `start_grace_mins` int NOT NULL DEFAULT '0',
  `end_grace_mins` int NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` varchar(50) NOT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`shift_id`),
  KEY `idx_shift_lookup` (`employee_id`,`start_date`,`end_date`,`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_accounts`
--

DROP TABLE IF EXISTS `user_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_accounts` (
  `user_accounts_id` int NOT NULL AUTO_INCREMENT,
  `user_display_name` varchar(45) DEFAULT NULL,
  `user_password` varchar(5000) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `employee_id` int DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `active` tinyint DEFAULT NULL,
  `role_id` int DEFAULT NULL,
  `otp` int DEFAULT NULL,
  `otp_generated_on` datetime DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(100) DEFAULT NULL,
  `last_login_on` datetime DEFAULT NULL,
  PRIMARY KEY (`user_accounts_id`),
  KEY `idx_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=76 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping events for database 'staffdesk'
--

--
-- Dumping routines for database 'staffdesk'
--
/*!50003 DROP PROCEDURE IF EXISTS `sp_action_leave_request` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_action_leave_request`(
    IN p_leave_request_id INT,
    IN p_status ENUM('Pending', 'Approved', 'Rejected'),
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    UPDATE leave_requests
    SET status = p_status,
        approved_by_id = p_approver_id,
        approved_on = NOW(),
        reason = CONCAT(COALESCE(reason, ''), ' | Approver Remarks: ', COALESCE(p_remarks, ''))
    WHERE leave_request_id = p_leave_request_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_action_payroll_period` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_action_payroll_period`(
    IN p_period_id INT,
    IN p_action VARCHAR(30), -- 'submitted', 'verified', 'approved', 'paid', 'rejected'
    IN p_action_by INT,
    IN p_remarks VARCHAR(500)
)
BEGIN
    DECLARE v_current_status VARCHAR(30);
    DECLARE v_new_status VARCHAR(30);
    
    SELECT status INTO v_current_status FROM payroll_period WHERE period_id = p_period_id;
    
    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payroll period not found';
    END IF;
    
    -- Map period state machine
    IF p_action = 'submitted' THEN
        SET v_new_status = 'processing';
    ELSEIF p_action = 'verified' THEN
        SET v_new_status = 'processing';
    ELSEIF p_action = 'approved' THEN
        SET v_new_status = 'completed';
    ELSEIF p_action = 'paid' THEN
        SET v_new_status = 'locked';
    ELSEIF p_action = 'rejected' THEN
        SET v_new_status = 'draft';
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid action specified';
    END IF;
    
    -- Update period status
    UPDATE payroll_period SET status = v_new_status WHERE period_id = p_period_id;
    
    -- Update disbursement records status to match
    UPDATE salary_disbursement 
    SET status = p_action,
        prepared_by = CASE WHEN p_action = 'submitted' THEN p_action_by ELSE prepared_by END,
        prepared_on = CASE WHEN p_action = 'submitted' THEN NOW() ELSE prepared_on END,
        verified_by = CASE WHEN p_action = 'verified' THEN p_action_by ELSE verified_by END,
        verified_on = CASE WHEN p_action = 'verified' THEN NOW() ELSE verified_on END,
        verified_remarks = CASE WHEN p_action = 'verified' THEN p_remarks ELSE verified_remarks END,
        approved_by = CASE WHEN p_action = 'approved' THEN p_action_by ELSE approved_by END,
        approved_on = CASE WHEN p_action = 'approved' THEN NOW() ELSE approved_on END,
        approved_remarks = CASE WHEN p_action = 'approved' THEN p_remarks ELSE approved_remarks END,
        rejected_by = CASE WHEN p_action = 'rejected' THEN p_action_by ELSE rejected_by END,
        rejected_on = CASE WHEN p_action = 'rejected' THEN NOW() ELSE rejected_on END,
        rejected_remarks = CASE WHEN p_action = 'rejected' THEN p_remarks ELSE rejected_remarks END,
        payment_date = CASE WHEN p_action = 'paid' THEN CURRENT_DATE() ELSE payment_date END,
        remarks = CASE WHEN p_action = 'paid' THEN p_remarks ELSE remarks END
    WHERE period_id = p_period_id;
    
    -- Update loan balances and mark as paid if action is paid
    IF p_action = 'paid' THEN
        -- Loop over disbursements for this period and update loans
        -- We will do a bulk update:
        UPDATE employee_loan el
        JOIN (
            SELECT sd.employee_id, 
                   JSON_UNQUOTE(JSON_EXTRACT(sd.deductions_json, '$.LoanEMI')) AS loan_emi
            FROM salary_disbursement sd
            WHERE sd.period_id = p_period_id
        ) sub ON el.employee_id = sub.employee_id
        SET el.total_paid_amount = el.total_paid_amount + CAST(sub.loan_emi AS DECIMAL(15,2)),
            el.status = CASE WHEN el.total_paid_amount + CAST(sub.loan_emi AS DECIMAL(15,2)) >= el.loan_amount THEN 'closed' ELSE el.status END
        WHERE el.status = 'active' AND CAST(sub.loan_emi AS DECIMAL(15,2)) > 0;
    END IF;
    
    -- Insert into approval logs for tracking
    INSERT INTO payroll_approval_log (
        disbursement_id, period_id, action, action_by, action_on, remarks, previous_status, new_status
    )
    SELECT 
        disbursement_id, p_period_id, p_action, p_action_by, NOW(), p_remarks, v_current_status, p_action
    FROM salary_disbursement
    WHERE period_id = p_period_id;
    
    SELECT ROW_COUNT() AS updated_disbursements;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_apply_leave` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin_test`@`localhost` PROCEDURE `sp_apply_leave`(
    IN p_employee_id          INT,
    IN p_leave_type           VARCHAR(50),
    IN p_start_date           DATE,
    IN p_end_date             DATE,
    IN p_total_days           DECIMAL(5,2),
    IN p_reason               TEXT,
    IN p_attachment_path      VARCHAR(512),
    IN p_substitute_id        INT,
    IN p_approver_1_id        INT,
    IN p_approver_2_id        INT
)
BEGIN
    DECLARE v_principal_id INT;
    DECLARE v_manager_id   INT;
    DECLARE v_a1           INT;
    DECLARE v_a2           INT;

    /* Allow only current month and future dates */
    IF p_start_date < DATE_FORMAT(CURDATE(), '%Y-%m-01') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Leave can only be applied within the current month.';
    END IF;

    SELECT reporting_manager_id
    INTO v_manager_id
    FROM employee
    WHERE employee_id = p_employee_id;

    /* Adjust this query if your table is roles instead of app_role */
    SELECT e.employee_id
    INTO v_principal_id
    FROM employee e
    JOIN app_role r ON e.role_id = r.role_id
    WHERE r.role IN ('Principal','principal')
      AND e.active = 1
    LIMIT 1;

    SET v_a1 = COALESCE(p_approver_1_id, v_manager_id, v_principal_id);
    SET v_a2 = p_approver_2_id;

    IF p_approver_1_id IS NULL THEN

        SELECT
            COALESCE(
                eac.approver_1_id,
                v_manager_id,
                v_principal_id
            ),
            eac.approver_2_id
        INTO v_a1, v_a2
        FROM (SELECT 1) d
        LEFT JOIN employee_approver_configs eac
            ON eac.employee_id = p_employee_id
           AND eac.request_type = 'LEAVE';

        SET v_a1 = COALESCE(
            v_a1,
            v_manager_id,
            v_principal_id
        );

    END IF;

    INSERT INTO leave_requests (
        employee_id,
        leave_type,
        start_date,
        end_date,
        total_days,
        reason,
        attachment_path,
        status,
        applied_on,
        substitute_employee_id,
        approver_1_id,
        approver_2_id,
        current_level
    )
    VALUES (
        p_employee_id,
        p_leave_type,
        p_start_date,
        p_end_date,
        p_total_days,
        p_reason,
        p_attachment_path,
        'Pending',
        NOW(),
        p_substitute_id,
        v_a1,
        v_a2,
        1
    );

    SELECT LAST_INSERT_ID() AS leave_request_id;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_apply_leave_approval` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_apply_leave_approval`(
    IN p_leave_request_id INT
)
BEGIN

    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_leave_type     VARCHAR(50);
    DECLARE v_leave_half     ENUM('FullDay','FirstHalf','SecondHalf');
    DECLARE v_total_days     DECIMAL(5,2);
    DECLARE v_status         VARCHAR(20);

    DECLARE v_current_date   DATE;

    
    SELECT
        employee_id,
        start_date,
        end_date,
        leave_type,
        COALESCE(leave_half, 'FullDay'),
        total_days,
        status
    INTO
        v_emp_id,
        v_start_date,
        v_end_date,
        v_leave_type,
        v_leave_half,
        v_total_days,
        v_status
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    
    IF v_status != 'Approved' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Leave request is not in Approved status';
    END IF;

    SET v_current_date = v_start_date;

    date_loop: WHILE v_current_date <= v_end_date DO

        
        IF EXISTS (
            SELECT 1 
            FROM holiday_master
            WHERE v_current_date BETWEEN holiday_start_date AND holiday_end_date
              AND is_active = 1
        ) THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        
        IF v_leave_half = 'FullDay' THEN

            INSERT INTO attendance_daily (
                employee_id, date,
                shift_type, status,
                deduction_days
            )
            VALUES (
                v_emp_id, v_current_date,
                'Absent',
                'Leave',
                0
            )
            ON DUPLICATE KEY UPDATE
                shift_type = 'Absent',
                status = 'Leave',
                deduction_days = 0;

        
        ELSEIF v_leave_half = 'FirstHalf' THEN

            INSERT INTO attendance_daily (
                employee_id, date,
                shift_type, status,
                deduction_days
            )
            VALUES (
                v_emp_id, v_current_date,
                'FirstHalf',
                'Leave',
                0.5   
            )
            ON DUPLICATE KEY UPDATE
                shift_type = 'FirstHalf',
                status = 'Leave',
                deduction_days = 0.5;

        
        ELSEIF v_leave_half = 'SecondHalf' THEN

            INSERT INTO attendance_daily (
                employee_id, date,
                shift_type, status,
                deduction_days
            )
            VALUES (
                v_emp_id, v_current_date,
                'SecondHalf',
                'Leave',
                0.5   
            )
            ON DUPLICATE KEY UPDATE
                shift_type = 'SecondHalf',
                status = 'Leave',
                deduction_days = 0.5;

        END IF;

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);

    END WHILE;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_apply_regularization` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_apply_regularization`(
    IN p_reg_id     INT,   
    IN p_approved_by INT   
)
BEGIN
    
    DECLARE v_emp_id   INT;
    DECLARE v_date     DATE;
    DECLARE v_in_time  TIME;
    DECLARE v_out_time TIME;
    DECLARE v_reg_type ENUM('Regularization','OnDuty');
    DECLARE v_regularization_shift_type ENUM('FullDay','FirstHalf','SecondHalf');
    DECLARE v_status   VARCHAR(20);

    SELECT employee_id, date, requested_in_time, requested_out_time,
           request_type, status, regularization_shift_type
    INTO   v_emp_id, v_date, v_in_time, v_out_time, v_reg_type, v_status,v_regularization_shift_type
    FROM   attendance_regularization
    WHERE  id = p_reg_id;

    
    IF v_status != 'Approved' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regularization request is not in Approved status';
    END IF;

    
    UPDATE attendance_regularization
    SET    status      = 'Approved',
           approved_by = p_approved_by,
           approved_on = NOW()
    WHERE  id = p_reg_id;

    
    SET @emp_shift_id = -1;
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM shift_master
            WHERE is_active = 1
              AND start_date <= v_date
              AND (end_date IS NULL OR end_date >= v_date)
              AND employee_id = v_emp_id
        ) THEN v_emp_id ELSE -1
    END INTO @emp_shift_id;

    
    SET @fd_start = '09:00:00'; SET @fd_end = '16:30:00';
    SET @fd_start_grace = 15;   SET @fd_end_grace = 25;
    SELECT start_time, end_time, start_grace_mins, end_grace_mins
    INTO   @fd_start, @fd_end, @fd_start_grace, @fd_end_grace
    FROM   shift_master
    WHERE  is_active = 1 AND start_date <= v_date
      AND  (end_date IS NULL OR end_date >= v_date)
      AND  employee_id = @emp_shift_id AND shift_type = 'FullDay' LIMIT 1;

    
    SET @fh_start = '09:00:00'; SET @fh_end = '13:00:00';
    SET @fh_start_grace = 15;   SET @fh_end_grace = 5;
    SELECT start_time, end_time, start_grace_mins, end_grace_mins
    INTO   @fh_start, @fh_end, @fh_start_grace, @fh_end_grace
    FROM   shift_master
    WHERE  is_active = 1 AND start_date <= v_date
      AND  (end_date IS NULL OR end_date >= v_date)
      AND  employee_id = @emp_shift_id AND shift_type = 'FirstHalf' LIMIT 1;

    
    SET @sh_start = '13:30:00'; SET @sh_end = '16:30:00';
    SET @sh_start_grace = 0;    SET @sh_end_grace = 5;
    SELECT start_time, end_time, start_grace_mins, end_grace_mins
    INTO   @sh_start, @sh_end, @sh_start_grace, @sh_end_grace
    FROM   shift_master
    WHERE  is_active = 1 AND start_date <= v_date
      AND  (end_date IS NULL OR end_date >= v_date)
      AND  employee_id = @emp_shift_id AND shift_type = 'SecondHalf' LIMIT 1;

    
    SET @fd_grace_in  = CAST(ADDTIME(@fd_start, SEC_TO_TIME(@fd_start_grace * 60)) AS TIME);
    SET @fd_grace_out = CAST(SUBTIME(@fd_end,   SEC_TO_TIME(@fd_end_grace   * 60)) AS TIME);
    SET @fh_grace_in  = CAST(ADDTIME(@fh_start, SEC_TO_TIME(@fh_start_grace * 60)) AS TIME);
    SET @fh_grace_out = CAST(SUBTIME(@fh_end,   SEC_TO_TIME(@fh_end_grace   * 60)) AS TIME);
    SET @sh_grace_in  = CAST(ADDTIME(@sh_start, SEC_TO_TIME(@sh_start_grace * 60)) AS TIME);
    SET @sh_grace_out = CAST(SUBTIME(@sh_end,   SEC_TO_TIME(@sh_end_grace   * 60)) AS TIME);

    SET @first_in  = CAST(v_in_time  AS TIME);
    SET @last_out  = CAST(v_out_time AS TIME);

    
    IF v_reg_type = 'OnDuty' THEN
        SET @shift_type = 'FullDay';
        SET @deduction  = 0;
        SET @is_late    = 0; SET @late_minutes  = 0;
        SET @is_early   = 0; SET @early_minutes = 0;
        SET @overtime_minutes = 0;
        SET @worked_mins = TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(v_date, @first_in),
            TIMESTAMP(v_date, @last_out));

    
    ELSE
        SET @no_punch_out = IF(@first_in = @last_out OR v_out_time IS NULL, 1, 0);

        
        IF @first_in <= @fd_grace_in AND @last_out >= @fd_grace_out AND @no_punch_out = 0 THEN
            SET @shift_type = 'FullDay';  SET @deduction = 0;
        ELSEIF @first_in <= @fh_grace_in AND @last_out >= @fh_grace_out
               AND @last_out < @fd_grace_out AND @no_punch_out = 0 THEN
            SET @shift_type = 'FirstHalf'; SET @deduction = 0.5;
        ELSEIF @first_in > @fh_grace_in AND @first_in <= @sh_grace_in
               AND @last_out >= @sh_grace_out AND @no_punch_out = 0 THEN
            SET @shift_type = 'SecondHalf'; SET @deduction = 0.5;
        ELSE
            SET @shift_type = 'Absent'; SET @deduction = 1;
        END IF;

        
        SET @is_late = 0; SET @late_minutes = 0;
        IF @shift_type IN ('FullDay','FirstHalf','Absent') THEN
            IF @first_in > @fd_grace_in THEN
                SET @is_late = 1;
                SET @late_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(v_date, @fd_start), TIMESTAMP(v_date, @first_in));
            END IF;
        END IF;
        IF @shift_type = 'SecondHalf' THEN
            IF @first_in > @sh_grace_in THEN
                SET @is_late = 1;
                SET @late_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(v_date, @sh_start), TIMESTAMP(v_date, @first_in));
            END IF;
        END IF;

        SET @is_early = 0; SET @early_minutes = 0;
        IF @shift_type = 'FullDay' AND @last_out < @fd_grace_out THEN
            SET @is_early = 1;
            SET @early_minutes = TIMESTAMPDIFF(MINUTE,
                TIMESTAMP(v_date, @last_out), TIMESTAMP(v_date, @fd_end));
        END IF;
        IF @shift_type IN ('FirstHalf','SecondHalf','Absent') THEN
            IF @last_out < @fd_grace_out THEN
                SET @is_early = 1;
                SET @early_minutes = TIMESTAMPDIFF(MINUTE,
                    TIMESTAMP(v_date, @last_out), TIMESTAMP(v_date, @fd_end));
            END IF;
        END IF;

        
        IF @is_late = 1 AND @is_early = 1 THEN SET @deduction = @deduction + 0.5; END IF;
        IF @deduction > 1.0 THEN SET @deduction = 1.0; END IF;

        
        SET @overtime_minutes = 0;
        IF @shift_type = 'FullDay' AND @last_out > CAST(@fd_end AS TIME) THEN
            SET @overtime_minutes = TIMESTAMPDIFF(MINUTE,
                TIMESTAMP(v_date, @fd_end), TIMESTAMP(v_date, @last_out));
        END IF;

        
        SET @worked_mins = 0;
        IF @no_punch_out = 0 THEN
            SET @worked_mins = TIMESTAMPDIFF(MINUTE,
                TIMESTAMP(v_date, @first_in), TIMESTAMP(v_date, @last_out));
        END IF;
    END IF;

    
    UPDATE attendance_daily
    SET
        first_in_time        = @first_in,
        last_out_time        = IF(v_out_time IS NULL, NULL, @last_out),
        worked_mins          = @worked_mins,
        shift_type           = @shift_type,
        status               = IF(@shift_type = 'Absent', 'Absent', 'Present'),
        is_late              = @is_late,
        late_minutes         = @late_minutes,
        is_early_leaving     = @is_early,
        early_minutes        = @early_minutes,
        overtime_minutes     = @overtime_minutes,
        deduction_days       = @deduction,
        is_regularized       = 1,
        is_regularize_type   = v_reg_type,
        regularization_shift_type=v_regularization_shift_type
    WHERE employee_id = v_emp_id
      AND date        = v_date;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_approve_leave` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_approve_leave`(
    IN p_leave_request_id INT,
    IN p_approved_by      INT,
    IN p_action           ENUM('Approved','Rejected'),
    IN p_rejection_reason TEXT,
    IN p_substitute_id    INT
)
proc: BEGIN

    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_leave_type     VARCHAR(50);
    DECLARE v_leave_half     VARCHAR(20);
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_current_date   DATE;
    DECLARE v_is_paid        TINYINT DEFAULT 1;

    -- ─── Transaction Management ──────────────────────────────────────────────
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- ─── Load and validate the request ───────────────────────────────────────
    SELECT
        employee_id,
        start_date,
        end_date,
        leave_type,
        COALESCE(leave_half_type, 'FullDay'),
        status,
        is_paid
    INTO
        v_emp_id,
        v_start_date,
        v_end_date,
        v_leave_type,
        v_leave_half,
        v_current_status,
        v_is_paid
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Leave request not found';
    END IF;

    IF v_current_status != 'Pending' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only Pending requests can be approved or rejected';
    END IF;

    IF p_action = 'Rejected' AND (p_rejection_reason IS NULL OR TRIM(p_rejection_reason) = '') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rejection reason is required when rejecting a leave request';
    END IF;

    -- ─── Update leave request status ─────────────────────────────────────────
    UPDATE leave_requests
    SET
        status                 = p_action,
        approved_by_id         = p_approved_by,
        approved_on            = NOW(),
        rejection_reason       = IF(p_action = 'Rejected', p_rejection_reason, NULL),
        substitute_employee_id = COALESCE(p_substitute_id, substitute_employee_id)
    WHERE leave_request_id = p_leave_request_id;

    -- ── Phase 1: Validation Loop (Check for conflicts BEFORE updating balance) ──
    IF p_action = 'Approved' THEN
        SET v_current_date = v_start_date;
        validation_loop: WHILE v_current_date <= v_end_date DO
            SET @reg_shift = NULL;
            SET @is_leave = 0;
            SET @leave_shift = NULL;

            SELECT regularization_shift_type, is_leave, leave_shift_type 
            INTO @reg_shift, @is_leave, @leave_shift
            FROM   attendance_daily
            WHERE  employee_id = v_emp_id AND date = v_current_date
            FOR UPDATE;

            -- Check Regularization/On-Duty Conflict
            IF @reg_shift IS NOT NULL THEN
                IF @reg_shift = 'FullDay' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: One or more days are already fully regularized/on-duty';
                END IF;

                IF @reg_shift = v_leave_half AND v_leave_half != 'FullDay' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: This half of the day is already regularized/on-duty';
                END IF;
                
                IF v_leave_half = 'FullDay' AND @reg_shift != 'FullDay' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: A part of this day is already regularized/on-duty. Cannot apply full-day leave.';
                END IF;
            END IF;

            -- Check Leave Conflict
            IF @is_leave = 1 THEN
                IF @leave_shift = 'FullDay' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: One or more days already have an approved leave';
                END IF;

                IF @leave_shift = v_leave_half AND v_leave_half != 'FullDay' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: An approved leave already exists for this half-day';
                END IF;

                IF v_leave_half = 'FullDay' AND @leave_shift != 'FullDay' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflict: A part of this day already has an approved leave. Cannot apply full-day leave.';
                END IF;
            END IF;

            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
        END WHILE;

        -- ── Phase 2: Update employee_leaves table (Safe now because Phase 1 passed) ──
        SET @v_total_days = 0;
        SELECT total_days INTO @v_total_days FROM leave_requests WHERE leave_request_id = p_leave_request_id;
        
        INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
        VALUES (v_emp_id, v_leave_type, DATE_FORMAT(NOW(), '%m-%Y'), 0, 0, @v_total_days)
        ON DUPLICATE KEY UPDATE 
            leaves_taken = leaves_taken + @v_total_days;

        -- ── Phase 3: Update attendance_daily ─────────────────────────────────────
        SET v_current_date = v_start_date;
        date_loop: WHILE v_current_date <= v_end_date DO
            -- ── Skip weekends and holidays ────────────────────────────────────────
            SET @existing_status = NULL;
            SELECT status INTO @existing_status FROM attendance_daily
            WHERE employee_id = v_emp_id AND date = v_current_date LIMIT 1;

            IF @existing_status IN ('WeekEnd','Public Holiday','Exceptional Holiday') THEN
                SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
                ITERATE date_loop;
            END IF;

            IF EXISTS (
                SELECT 1 FROM holiday_master
                WHERE v_current_date BETWEEN holiday_start_date AND holiday_end_date
                  AND is_active = 1 AND employee_id IN (v_emp_id, -1)
            ) THEN
                SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
                ITERATE date_loop;
            END IF;

            -- Read ALL existing coverage data
            SET @first_in = NULL; SET @last_out = NULL; SET @worked_mins = 0;
            SET @cur_shift = NULL; SET @cur_status = NULL;
            SET @reg_shift = NULL; SET @od_shift = NULL;
            SET @is_leave_existing = 0; SET @leave_shift_existing = NULL;

            SELECT 
                first_in_time, last_out_time, worked_mins, 
                shift_type, status,
                regularization_shift_type, onduty_shift_type,
                is_leave, leave_shift_type
            INTO 
                @first_in, @last_out, @worked_mins,
                @cur_shift, @cur_status,
                @reg_shift, @od_shift,
                @is_leave_existing, @leave_shift_existing
            FROM attendance_daily
            WHERE employee_id = v_emp_id AND date = v_current_date
            LIMIT 1;

            -- ── Calculate Merged Coverage ────────────────────────────────────────
            SET @v_first_half_covered = (
                (COALESCE(@cur_status, '') = 'Present' AND @cur_shift IN ('FirstHalf', 'FullDay')) OR
                (COALESCE(@reg_shift, '') IN ('FirstHalf', 'FullDay')) OR
                (COALESCE(@od_shift, '') IN ('FirstHalf', 'FullDay')) OR
                (COALESCE(@is_leave_existing, 0) = 1 AND COALESCE(@leave_shift_existing, '') IN ('FirstHalf', 'FullDay')) OR
                (COALESCE(v_is_paid, 1) = 1 AND v_leave_half IN ('FirstHalf', 'FullDay'))
            );

            SET @v_second_half_covered = (
                (COALESCE(@cur_status, '') = 'Present' AND @cur_shift IN ('SecondHalf', 'FullDay')) OR
                (COALESCE(@reg_shift, '') IN ('SecondHalf', 'FullDay')) OR
                (COALESCE(@od_shift, '') IN ('SecondHalf', 'FullDay')) OR
                (COALESCE(@is_leave_existing, 0) = 1 AND COALESCE(@leave_shift_existing, '') IN ('SecondHalf', 'FullDay')) OR
                (COALESCE(v_is_paid, 1) = 1 AND v_leave_half IN ('SecondHalf', 'FullDay'))
            );

            SET @final_deduct = IF(@v_first_half_covered AND @v_second_half_covered, 0.00, 0.50);
            IF NOT @v_first_half_covered AND NOT @v_second_half_covered THEN SET @final_deduct = 1.00; END IF;

            SET @final_shift = 'Absent';
            IF @v_first_half_covered AND @v_second_half_covered THEN SET @final_shift = 'FullDay';
            ELSEIF @v_first_half_covered THEN SET @final_shift = 'FirstHalf';
            ELSEIF @v_second_half_covered THEN SET @final_shift = 'SecondHalf';
            END IF;

            SET @final_status = IF(@final_shift = 'FullDay' OR @cur_shift = 'FullDay', 'Present', 'Leave');

            -- Final Update
            INSERT INTO attendance_daily (
                employee_id, date, first_in_time, last_out_time, worked_mins,
                shift_type, status, is_late, late_minutes, is_early_leaving, early_minutes,
                overtime_minutes, deduction_days, is_worked_on_holiday,
                is_leave, leave_shift_type
            ) VALUES (
                v_emp_id, v_current_date, @first_in, @last_out, @worked_mins,
                @final_shift, @final_status, 0, 0, 0, 0, 0,
                @final_deduct, 0, 1, v_leave_half
            )
            ON DUPLICATE KEY UPDATE
                shift_type = @final_shift,
                status = @final_status,
                deduction_days = @final_deduct,
                is_leave = 1,
                leave_shift_type = IF(v_leave_half = 'FullDay', 'FullDay', 
                                      IF(@is_leave_existing = 1 AND @leave_shift_existing != v_leave_half, 'FullDay', v_leave_half));

            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
        END WHILE date_loop;
    END IF;

    COMMIT;

    -- ─── Return summary ───────────────────────────────────────────────────────
    SELECT
        p_leave_request_id                          AS leave_request_id,
        v_emp_id                                    AS employee_id,
        v_start_date                                AS start_date,
        v_end_date                                  AS end_date,
        v_leave_half                                AS leave_half_type,
        p_action                                    AS status,
        DATEDIFF(v_end_date, v_start_date) + 1      AS calendar_days,
        (SELECT total_days FROM leave_requests
         WHERE leave_request_id = p_leave_request_id) AS working_days_deducted;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_approve_leave_1` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_approve_leave_1`(
    IN p_leave_request_id INT,
    IN p_approved_by      INT,
    IN p_action           ENUM('Approved','Rejected'),
    IN p_rejection_reason TEXT
)
proc: BEGIN

    DECLARE v_emp_id         INT;
    DECLARE v_start_date     DATE;
    DECLARE v_end_date       DATE;
    DECLARE v_leave_type     VARCHAR(50);
    DECLARE v_leave_half     ENUM('FullDay','FirstHalf','SecondHalf');
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_current_date   DATE;

    
    SELECT
        employee_id,
        start_date,
        end_date,
        leave_type,
        COALESCE(leave_half_type, 'FullDay'),
        status
    INTO
        v_emp_id,
        v_start_date,
        v_end_date,
        v_leave_type,
        v_leave_half,
        v_current_status
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Leave request not found';
    END IF;

    IF v_current_status != 'Pending' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only Pending requests can be approved or rejected';
    END IF;

    IF p_action = 'Rejected' AND (p_rejection_reason IS NULL OR TRIM(p_rejection_reason) = '') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rejection reason is required when rejecting a leave request';
    END IF;

    
    UPDATE leave_requests
    SET
        status           = p_action,
        approved_by_id   = p_approved_by,
        approved_on      = NOW(),
        rejection_reason = IF(p_action = 'Rejected', p_rejection_reason, NULL)
    WHERE leave_request_id = p_leave_request_id;

    
    IF p_action = 'Rejected' THEN
        SELECT
            p_leave_request_id AS leave_request_id,
            'Rejected'         AS status;
        LEAVE proc;
    END IF;

    
    
    
    SET v_current_date = v_start_date;

    date_loop: WHILE v_current_date <= v_end_date DO

        
        SET @is_regularized = 0;

        SELECT is_regularized INTO @is_regularized
        FROM   attendance_daily
        WHERE  employee_id = v_emp_id
          AND  date        = v_current_date
        LIMIT  1;

        IF @is_regularized = 1 THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        
        SET @holiday_type    = NULL;
        SET @existing_status = NULL;

        SELECT status INTO @existing_status
        FROM   attendance_daily
        WHERE  employee_id = v_emp_id
          AND  date        = v_current_date
        LIMIT  1;

        IF @existing_status IN ('WeekEnd','Public Holiday','Exceptional Holiday') THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        SELECT holiday_type INTO @holiday_type
        FROM   holiday_master
        WHERE  v_current_date BETWEEN holiday_start_date AND holiday_end_date
          AND  is_active   = 1
          AND  employee_id IN (v_emp_id, -1)
        ORDER BY CASE WHEN employee_id = -1 THEN 1 ELSE 2 END
        LIMIT 1;

        IF @holiday_type IS NOT NULL THEN
            SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
            ITERATE date_loop;
        END IF;

        
        SET @first_in    = NULL;
        SET @last_out    = NULL;
        SET @worked_mins = 0;
        SET @cur_shift   = NULL;
        SET @cur_deduct  = 0;

        SELECT
            first_in_time,
            last_out_time,
            worked_mins,
            shift_type,
            deduction_days
        INTO
            @first_in,
            @last_out,
            @worked_mins,
            @cur_shift,
            @cur_deduct
        FROM attendance_daily
        WHERE employee_id = v_emp_id
          AND date        = v_current_date
        LIMIT 1;

        
        
        
        IF v_leave_half = 'FullDay' THEN

            INSERT INTO attendance_daily (
                employee_id, date,
                first_in_time, last_out_time, worked_mins,
                shift_type, status,
                is_late, late_minutes,
                is_early_leaving, early_minutes,
                overtime_minutes, deduction_days,
                is_worked_on_holiday,
                is_regularized, is_regularize_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                'Absent', 'Leave',
                0, 0, 0, 0, 0, 0,
                0, 0, NULL
            )
            ON DUPLICATE KEY UPDATE
                shift_type         = 'Absent',
                status             = 'Leave',
                is_late            = 0,
                late_minutes       = 0,
                is_early_leaving   = 0,
                early_minutes      = 0,
                overtime_minutes   = 0,
                deduction_days     = 0,
                is_regularized     = 0,
                is_regularize_type = NULL;

        
        
        
        ELSEIF v_leave_half = 'FirstHalf' THEN

            SET @final_shift  = IF(@cur_shift IN ('SecondHalf','FullDay'), 'FullDay', 'FirstHalf');
            SET @final_status = IF(@cur_shift IN ('SecondHalf','FullDay'), 'Present', 'Leave');
            SET @final_deduct = 0;

            INSERT INTO attendance_daily (
                employee_id, date,
                first_in_time, last_out_time, worked_mins,
                shift_type, status,
                is_late, late_minutes,
                is_early_leaving, early_minutes,
                overtime_minutes, deduction_days,
                is_worked_on_holiday,
                is_regularized, is_regularize_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                @final_shift, @final_status,
                0, 0, 0, 0, 0,
                @final_deduct,
                0, 0, NULL
            )
            ON DUPLICATE KEY UPDATE
                shift_type         = @final_shift,
                status             = @final_status,
                is_late            = 0,
                late_minutes       = 0,
                is_early_leaving   = 0,
                early_minutes      = 0,
                deduction_days     = @final_deduct,
                is_regularized     = 0,
                is_regularize_type = NULL;

        
        
        
        ELSEIF v_leave_half = 'SecondHalf' THEN

            SET @final_shift  = IF(@cur_shift IN ('FirstHalf','FullDay'), 'FullDay', 'SecondHalf');
            SET @final_status = IF(@cur_shift IN ('FirstHalf','FullDay'), 'Present', 'Leave');
            SET @final_deduct = 0;

            INSERT INTO attendance_daily (
                employee_id, date,
                first_in_time, last_out_time, worked_mins,
                shift_type, status,
                is_late, late_minutes,
                is_early_leaving, early_minutes,
                overtime_minutes, deduction_days,
                is_worked_on_holiday,
                is_regularized, is_regularize_type
            )
            VALUES (
                v_emp_id, v_current_date,
                @first_in, @last_out, @worked_mins,
                @final_shift, @final_status,
                0, 0, 0, 0, 0,
                @final_deduct,
                0, 0, NULL
            )
            ON DUPLICATE KEY UPDATE
                shift_type         = @final_shift,
                status             = @final_status,
                is_late            = 0,
                late_minutes       = 0,
                is_early_leaving   = 0,
                early_minutes      = 0,
                deduction_days     = @final_deduct,
                is_regularized     = 0,
                is_regularize_type = NULL;

        END IF;

        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);

    END WHILE date_loop;

    
    SELECT
        p_leave_request_id                          AS leave_request_id,
        v_emp_id                                    AS employee_id,
        v_start_date                                AS start_date,
        v_end_date                                  AS end_date,
        v_leave_half                                AS leave_half_type,
        'Approved'                                  AS status,
        DATEDIFF(v_end_date, v_start_date) + 1      AS calendar_days,
        (SELECT total_days FROM leave_requests
         WHERE leave_request_id = p_leave_request_id) AS working_days_deducted;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_approve_regularization` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_approve_regularization`(
    IN p_reg_id      INT,
    IN p_approved_by INT
)
BEGIN
    
    UPDATE attendance_regularization
    SET    status      = 'Approved',
           approved_by = p_approved_by,
           approved_on = NOW()
    WHERE  id     = p_reg_id
      AND  status = 'Pending';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Request not found or already processed';
    END IF;

    
    CALL sp_apply_regularization(p_reg_id, p_approved_by);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_cancel_leave` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_cancel_leave`(
    IN p_leave_request_id INT,
    IN p_cancelled_by      INT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_leave_type VARCHAR(50);
    DECLARE v_total_days DECIMAL(10,2);
    DECLARE v_status VARCHAR(20);
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;

    -- ─── Transaction Management ──────────────────────────────────────────────
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT employee_id, leave_type, total_days, status, start_date, end_date
    INTO v_emp_id, v_leave_type, v_total_days, v_status, v_start_date, v_end_date
    FROM leave_requests
    WHERE leave_request_id = p_leave_request_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leave request not found';
    END IF;

    IF v_status = 'Cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leave request is already cancelled';
    END IF;

    UPDATE leave_requests
    SET status = 'Cancelled',
        approved_by_id = p_cancelled_by,
        approved_on = NOW()
    WHERE leave_request_id = p_leave_request_id;

    IF v_status = 'Approved' THEN
        UPDATE employee_leaves
        SET leaves_taken = leaves_taken - v_total_days
        WHERE emp_id = v_emp_id 
          AND leave_type = v_leave_type 
          AND month_year = DATE_FORMAT(NOW(), '%m-%Y');
        
        UPDATE attendance_daily
        SET is_leave = 0,
            is_leave_type = NULL,
            leave_shift_type = NULL,
            status = CASE 
                WHEN regularization_shift_type IS NOT NULL OR onduty_shift_type IS NOT NULL OR (shift_type IS NOT NULL AND shift_type != 'Absent') THEN 'Present'
                ELSE 'Absent'
            END
        WHERE employee_id = v_emp_id 
          AND date BETWEEN v_start_date AND v_end_date
          AND is_leave = 1;
    END IF;

    COMMIT;

    SELECT p_leave_request_id AS leave_request_id, 'Cancelled' AS status;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_check_substitute_availability` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin_test`@`localhost` PROCEDURE `sp_check_substitute_availability`(
    IN p_substitute_id INT,
    IN p_start_date    DATE,
    IN p_end_date      DATE
)
BEGIN
    -- Returns rows if substitute has conflicting approved/pending leave
    SELECT
        lr.leave_request_id,
        lr.start_date,
        lr.end_date,
        lr.leave_type,
        lr.status
    FROM leave_requests lr
    WHERE lr.employee_id = p_substitute_id
      AND lr.status IN ('Pending','Approved')
      AND lr.start_date <= p_end_date
      AND lr.end_date   >= p_start_date
    LIMIT 5;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_create_department` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_create_department`(
    IN p_departmentname VARCHAR(45)
)
BEGIN
    INSERT INTO department (departmentname)
    VALUES (p_departmentname);

    SELECT LAST_INSERT_ID() AS department_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_create_designation` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_create_designation`(
    IN p_designation VARCHAR(45),
    IN p_created_by VARCHAR(45)
)
BEGIN
    INSERT INTO designation (designation, created_on, created_by)
    VALUES (p_designation, NOW(), p_created_by);

    SELECT LAST_INSERT_ID() AS designation_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_create_employee` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_create_employee`(
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
    IN p_email VARCHAR(200),
    IN p_role_id INT,
    IN p_designation_id INT,
    IN p_reporting_manager_id INT,
    IN p_joining_date DATE,
    IN p_active TINYINT,
    IN p_created_by VARCHAR(45),
    IN p_department_id INT,
    IN p_basic_pay DECIMAL(15,2)
)
BEGIN
    INSERT INTO employee (
        organization_id, employee_code, employee_name, email, role_id, 
        designation_id, reporting_manager_id, 
        joining_date, active, created_by, created_on, department_id, basic_pay
    ) VALUES (
        p_organization_id, p_employee_code, p_employee_name, p_email, p_role_id, 
        p_designation_id, p_reporting_manager_id, 
        p_joining_date, p_active, p_created_by, NOW(), p_department_id, p_basic_pay
    );

    SELECT LAST_INSERT_ID() AS employee_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_create_leave_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_create_leave_policy`(
    IN p_policy_name VARCHAR(245),
    IN p_policy_year INT,
    IN p_policy_value LONGTEXT,
    IN p_weekly_off TEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    INSERT INTO leave_policy (
        policy_name, policy_year, policy_value, weekly_off, active, created_on, created_by
    )
    VALUES (
        p_policy_name, p_policy_year, p_policy_value, p_weekly_off, 0, NOW(), p_created_by
    );
    
    SELECT LAST_INSERT_ID() AS leave_policy_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_create_role` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_create_role`(
    IN p_role VARCHAR(45)
)
BEGIN
    INSERT INTO app_role(role) VALUES(p_role);
    SELECT LAST_INSERT_ID() AS role_id, p_role AS role;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_department` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_delete_department`(
    IN p_department_id INT
)
BEGIN
    DELETE FROM department
    WHERE department_id = p_department_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_designation` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_delete_designation`(
    IN p_designation_id INT
)
BEGIN
    DELETE FROM designation
    WHERE designation_id = p_designation_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_employee` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_delete_employee`(
    IN p_employee_id INT
)
BEGIN
    DECLARE v_rows INT DEFAULT 0;

    
    UPDATE employee
    SET 
        active = 0,
        modified_on = NOW()
    WHERE employee_id = p_employee_id;

    SET v_rows = ROW_COUNT();

    
    UPDATE user_accounts
    SET 
        active = 0,
        created_on = created_on 
    WHERE employee_id = p_employee_id;

    SELECT v_rows AS affected_rows;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_exceptional_day` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_delete_exceptional_day`(IN p_exceptional_id INT)
BEGIN
    DELETE FROM exceptional_days WHERE exceptional_id = p_exceptional_id;
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_holiday` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_delete_holiday`(IN p_holiday_id INT)
BEGIN
    DELETE FROM holidays WHERE holiday_id = p_holiday_id;
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_leave_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_delete_leave_policy`(
    IN p_leave_policy_id INT
)
BEGIN
    DECLARE v_active TINYINT;
    
    SELECT active INTO v_active FROM leave_policy WHERE leave_policy_id = p_leave_policy_id;
    
    IF v_active = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete an active system policy';
    ELSE
        DELETE FROM leave_policy WHERE leave_policy_id = p_leave_policy_id;
        SELECT ROW_COUNT() AS affected_rows;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_approver_config` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin_test`@`localhost` PROCEDURE `sp_get_approver_config`(
    IN p_employee_id INT,
    IN p_request_type ENUM('LEAVE','REGULARISATION','ONDUTY')
)
BEGIN
    -- Returns configured approvers, or falls back to reporting_manager / principal
    DECLARE v_manager_id INT;
    DECLARE v_principal_id INT;

    SELECT reporting_manager_id INTO v_manager_id
    FROM employee WHERE employee_id = p_employee_id;

    SELECT e.employee_id INTO v_principal_id
    FROM employee e
    JOIN app_role r ON e.role_id = r.role_id
    WHERE r.role IN ('Principal','principal') AND e.active = 1
    LIMIT 1;

    SELECT
        COALESCE(eac.approver_1_id, v_manager_id, v_principal_id) AS approver_1_id,
        eac.approver_2_id,
        COALESCE(a1.employee_name, m.employee_name, p.employee_name) AS approver_1_name,
        a2.employee_name AS approver_2_name
    FROM (SELECT 1) dummy
    LEFT JOIN employee_approver_configs eac
        ON eac.employee_id = p_employee_id AND eac.request_type = p_request_type
    LEFT JOIN employee a1 ON a1.employee_id = eac.approver_1_id
    LEFT JOIN employee m  ON m.employee_id  = v_manager_id
    LEFT JOIN employee p  ON p.employee_id  = v_principal_id
    LEFT JOIN employee a2 ON a2.employee_id = eac.approver_2_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_attendance_settings` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_attendance_settings`()
BEGIN
    SELECT * FROM attendance_settings ORDER BY setting_key;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_attendance_summary` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_attendance_summary`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        COUNT(CASE WHEN UPPER(status) = 'PRESENT' THEN 1 END) AS present_count,
        COUNT(CASE WHEN UPPER(status) = 'ABSENT' THEN 1 END) AS absent_count,
        SUM(is_late) AS late_count,
        SUM(is_early_leaving) AS early_leaving_count,
        SUM(CASE WHEN regularization_shift_type IS NOT NULL THEN 1 ELSE 0 END) AS regularized_count,
        SUM(CASE WHEN onduty_shift_type IS NOT NULL THEN 1 ELSE 0 END) AS onduty_count,
        SUM(CASE 
            WHEN is_leave = 1 AND (leave_shift_type = 'FullDay' OR leave_shift_type IS NULL) THEN 1.0
            WHEN is_leave = 1 AND (leave_shift_type = 'FirstHalf' OR leave_shift_type = 'SecondHalf') THEN 0.5
            ELSE 0 
        END) AS leave_days,
        SUM(deduction_days) AS total_deductions
    FROM attendance_daily
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_departments` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_departments`()
BEGIN
    SELECT 
        department_id,
        departmentname
    FROM department
    ORDER BY department_id DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_department_by_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_department_by_id`(
    IN p_department_id INT
)
BEGIN
    SELECT 
        department_id,
        departmentname
    FROM department
    WHERE department_id = p_department_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_designations` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_designations`()
BEGIN
    SELECT 
        designation_id,
        designation,
        created_on,
        created_by
    FROM designation
    ORDER BY designation_id DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_designation_by_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_designation_by_id`(
    IN p_designation_id INT
)
BEGIN
    SELECT 
        designation_id,
        designation,
        created_on,
        created_by
    FROM designation
    WHERE designation_id = p_designation_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_designation_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_designation_policy`(
    IN p_designation_id INT
)
BEGIN
    SELECT lpd.*, lp.policy_name, lp.policy_year
    FROM leave_policy_designation lpd
    JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
    WHERE lpd.designation_id = p_designation_id AND lpd.active = 1;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_employees` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_employees`()
BEGIN
    SELECT 
        e.*,
        d.departmentname,
        r.role AS role_name,
        des.designation AS designation_name,
        m.employee_name AS manager_name
    FROM employee e
    LEFT JOIN department d ON e.department_id = d.department_id
    LEFT JOIN app_role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
    ORDER BY e.employee_id DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_employees_filtered` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_employees_filtered`(
    IN p_search_term VARCHAR(255),
    IN p_role_id INT,
    IN p_active_only TINYINT
)
BEGIN
    SELECT 
        e.*,
        d.departmentname,
        r.role AS role_name,
        des.designation AS designation_name,
        m.employee_name AS manager_name
    FROM employee e
    LEFT JOIN department d ON e.department_id = d.department_id
    LEFT JOIN app_role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
    WHERE 
        (p_search_term IS NULL OR p_search_term = '' OR e.employee_name LIKE CONCAT('%', p_search_term, '%') OR e.employee_code LIKE CONCAT('%', p_search_term, '%'))
        AND (p_role_id IS NULL OR p_role_id = 0 OR e.role_id = p_role_id)
        AND (p_active_only = 0 OR e.active = 1)
    ORDER BY e.employee_id DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_employee_adjustments` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_employee_adjustments`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        aj.*,
        e.employee_name as approver_name
    FROM attendance_adjustments aj
    LEFT JOIN employee e ON aj.approved_by_id = e.employee_id
    WHERE aj.employee_id = p_employee_id
      AND (p_month IS NULL OR MONTH(aj.date) = p_month)
      AND (p_year IS NULL OR YEAR(aj.date) = p_year)
    ORDER BY aj.requested_on DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_employee_attendance` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_employee_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN

    SELECT
        ad.*,

        (
            SELECT GROUP_CONCAT(
                CONCAT(
                    lr.leave_type,
                    ' (',
                    lr.leave_half_type,
                    ')'
                )
                SEPARATOR ', '
            )
            FROM leave_requests lr
            WHERE lr.employee_id = ad.employee_id
              AND lr.status = 'Approved'
              AND ad.date BETWEEN lr.start_date AND lr.end_date
        ) AS leave_details

    FROM attendance_daily ad

    WHERE ad.employee_id = p_employee_id
      AND MONTH(ad.date) = p_month
      AND YEAR(ad.date) = p_year

    ORDER BY ad.date DESC;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_employee_by_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_employee_by_id`(
    IN p_employee_id INT
)
BEGIN
    SELECT 
        e.*,
        d.departmentname,
        r.role AS role_name,
        des.designation AS designation_name,
        m.employee_name AS manager_name
    FROM employee e
    LEFT JOIN department d ON e.department_id = d.department_id
    LEFT JOIN app_role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    LEFT JOIN employee m ON e.reporting_manager_id = m.employee_id
    WHERE e.employee_id = p_employee_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_employee_leave_requests` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_employee_leave_requests`(
    IN p_employee_id INT
)
BEGIN
    SELECT
        lr.*,
        e.employee_name as approver_name
    FROM leave_requests lr
    LEFT JOIN employee e ON lr.approved_by_id = e.employee_id
    WHERE lr.employee_id = p_employee_id
    ORDER BY lr.applied_on DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_employee_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_employee_policy`(
    IN p_employee_id INT
)
BEGIN
    SELECT lpe.*, lp.policy_name, lp.policy_year
    FROM leave_policy_employee lpe
    JOIN leave_policy lp ON lpe.leave_policy_id = lp.leave_policy_id
    WHERE lpe.employee_id = p_employee_id AND lpe.active = 1;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_exceptional_days` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_exceptional_days`(
    IN p_year INT
)
BEGIN
    SELECT * FROM exceptional_days
    WHERE (p_year IS NULL OR YEAR(holiday_date) = p_year)
    ORDER BY holiday_date ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_holidays` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_holidays`(
    IN p_year INT
)
BEGIN
    SELECT * FROM holidays
    WHERE (p_year IS NULL OR YEAR(holiday_date) = p_year)
    ORDER BY holiday_date ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_irregular_attendance` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_irregular_attendance`(
    IN p_employee_id INT,
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        attendance_id,
        employee_id,
        DATE_FORMAT(date, '%Y-%m-%d') as date,
        first_in_time,
        last_out_time,
        worked_mins,
        shift_type,
        status,
        deduction_days,
        CASE
            -- FULL DAY ABSENT
            WHEN deduction_days = 1.0 AND status = 'Absent' THEN 'Full Day Missing'
            
            -- INCOMPLETE PUNCH (Mandatory 1.0 Deduction)
            WHEN deduction_days = 1.0 AND (first_in_time = last_out_time OR first_in_time IS NULL OR last_out_time IS NULL)
                THEN 'Incomplete Punch'

            -- HALF DAY ABSENT / LEAVE
            WHEN deduction_days = 0.5 AND status = 'Absent' AND shift_type = 'FirstHalf' THEN 'Second Half Missing'
            WHEN deduction_days = 0.5 AND status = 'Absent' AND shift_type = 'SecondHalf' THEN 'First Half Missing'
            WHEN deduction_days = 0.5 AND status = 'Leave' AND shift_type = 'FirstHalf' THEN 'Second Half Leave'
            WHEN deduction_days = 0.5 AND status = 'Leave' AND shift_type = 'SecondHalf' THEN 'First Half Leave'

            -- IRREGULAR (Late/Early)
            WHEN is_late = 1 AND is_early_leaving = 1 THEN 'Late & Early Leaving'
            WHEN is_late = 1 THEN 'Late Arrival'
            WHEN is_early_leaving = 1 THEN 'Early Leaving'
            
            ELSE 'Other Anomaly'
        END AS final_status
    FROM attendance_daily
    WHERE employee_id = p_employee_id 
      AND MONTH(date) = p_month 
      AND YEAR(date) = p_year
      AND (deduction_days > 0 OR is_late = 1 OR is_early_leaving = 1)
      AND (regularization_shift_type IS NULL AND onduty_shift_type IS NULL AND is_leave = 0)
    ORDER BY date DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_leave_balance` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_leave_balance`(
    IN p_employee_id INT,
    IN p_year INT
)
BEGIN
    DECLARE v_designation_id INT;
    DECLARE v_role_id INT;
    DECLARE v_joining_date DATE;
    DECLARE v_policy_json LONGTEXT;
    DECLARE v_weekly_off_json TEXT;
    DECLARE v_months_active INT;
    DECLARE v_year_start DATE;
    DECLARE v_year_end DATE;

    
    SELECT designation_id, role_id, joining_date
    INTO v_designation_id, v_role_id, v_joining_date
    FROM employee WHERE employee_id = p_employee_id;

    
    SELECT policy_value, weekly_off INTO v_policy_json, v_weekly_off_json
    FROM (
        
        SELECT policy_value, weekly_off, 1 as priority
        FROM leave_policy_employee
        WHERE employee_id = p_employee_id AND active = 1
        UNION ALL
        
        SELECT lpd.policy_value, lpd.weekly_off, 2 as priority
        FROM leave_policy_designation lpd
        JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
        WHERE lpd.designation_id = v_designation_id AND lpd.active = 1 AND lp.policy_year = p_year
        UNION ALL
        
        SELECT lpr.policy_value, lpr.weekly_off, 3 as priority
        FROM leave_policy_role lpr
        JOIN leave_policy lp ON lpr.leave_policy_id = lp.leave_policy_id
        WHERE lpr.role_id = v_role_id AND lpr.active = 1 AND lp.policy_year = p_year
        UNION ALL
        
        SELECT policy_value, weekly_off, 4 as priority
        FROM leave_policy_system
        WHERE active = 1 AND policy_year = p_year
    ) as policies
    ORDER BY priority ASC
    LIMIT 1;

    IF v_policy_json IS NULL THEN
        SELECT 'No Policy Found' as leave_type, 0 as allocated, 0 as used, 0 as available, 0 as prorata_allocated;
    ELSE
        
        SET v_year_start = MAKEDATE(p_year, 1);
        SET v_year_end = MAKEDATE(p_year + 1, 1) - INTERVAL 1 DAY;

        IF v_joining_date IS NULL OR v_joining_date <= v_year_start THEN
            SET v_months_active = 12;
        ELSE
            SET v_months_active = 12 - MONTH(v_joining_date) + 1;
        END IF;

        
        WITH RECURSIVE PolicyLeaves AS (
            SELECT
                jt.leaveType,
                jt.leaveCount as base_allocated,
                ROUND((jt.leaveCount / 12) * v_months_active, 1) as allocated
            FROM JSON_TABLE(v_policy_json, '$[*]'
                COLUMNS (
                    leaveType VARCHAR(50) PATH '$.leaveType',
                    leaveCount INT PATH '$.leaveCount'
                )
            ) AS jt
        ),
        ApprovedLeaves AS (
            SELECT
                lr.leave_type,
                lr.start_date,
                lr.end_date
            FROM leave_requests lr
            WHERE lr.employee_id = p_employee_id
              AND lr.status = 'Approved'
              AND YEAR(lr.start_date) = p_year
        ),
        DateSeries AS (
            SELECT leave_type, start_date as leave_day, end_date FROM ApprovedLeaves
            WHERE start_date <= end_date
            UNION ALL
            SELECT leave_type, DATE_ADD(leave_day, INTERVAL 1 DAY), end_date FROM DateSeries
            WHERE DATE_ADD(leave_day, INTERVAL 1 DAY) <= end_date
        ),
        WorkingLeaveDays AS (
            SELECT
                ds.leave_type,
                ds.leave_day
            FROM DateSeries ds
            WHERE
                NOT JSON_CONTAINS(COALESCE(v_weekly_off_json, '["Sunday"]'), JSON_QUOTE(DAYNAME(ds.leave_day)))
                AND ds.leave_day NOT IN (SELECT holiday_date FROM holidays WHERE is_active = 1)
        ),
        UsedLeaves AS (
            SELECT leave_type, COUNT(*) as used
            FROM WorkingLeaveDays
            GROUP BY leave_type
        )
        SELECT
            pl.leaveType as leave_type,
            pl.base_allocated,
            pl.allocated as prorata_allocated,
            COALESCE(ul.used, 0) as used,
            (pl.allocated - COALESCE(ul.used, 0)) as available
        FROM PolicyLeaves pl
        LEFT JOIN UsedLeaves ul ON pl.leaveType = ul.leave_type;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_leave_encashments` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_leave_encashments`(
    IN p_employee_id INT
)
BEGIN
    SELECT
        le.*,
        e.employee_name as approver_name
    FROM leave_encashments le
    LEFT JOIN employee e ON le.approved_by_id = e.employee_id
    WHERE le.employee_id = p_employee_id
    ORDER BY le.requested_on DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_leave_policies` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_leave_policies`()
BEGIN
    SELECT * FROM leave_policy ORDER BY policy_year DESC, created_on DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_leave_types_by_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_leave_types_by_policy`(
    IN p_employee_id INT
)
BEGIN
    DECLARE v_designation_id INT;
    DECLARE v_policy_json LONGTEXT;

    
    SELECT designation_id INTO v_designation_id FROM employee WHERE employee_id = p_employee_id;

    
    SELECT policy_value INTO v_policy_json
    FROM (
        SELECT policy_value, 1 as priority
        FROM leave_policy_employee
        WHERE employee_id = p_employee_id AND active = 1
        UNION ALL
        SELECT lpd.policy_value, 2 as priority
        FROM leave_policy_designation lpd
        JOIN leave_policy lp ON lpd.leave_policy_id = lp.leave_policy_id
        WHERE lpd.designation_id = v_designation_id AND lpd.active = 1 AND lp.policy_year = YEAR(CURDATE())
        UNION ALL
        SELECT policy_value, 3 as priority
        FROM leave_policy_system
        WHERE active = 1 AND policy_year = YEAR(CURDATE())
    ) as policies
    ORDER BY priority ASC
    LIMIT 1;

    
    IF v_policy_json IS NOT NULL THEN
        SELECT 
            jt.leaveType as leave_type,
            jt.leaveCount as total_allocated
        FROM JSON_TABLE(v_policy_json, '$[*]'
            COLUMNS (
                leaveType VARCHAR(50) PATH '$.leaveType',
                leaveCount INT PATH '$.leaveCount'
            )
        ) AS jt;
    ELSE
        SELECT 'No Policy Found' as leave_type, 0 as total_allocated;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_potential_managers` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_potential_managers`(
    IN p_search_term VARCHAR(255),
    IN p_department_id INT,
    IN p_exclude_employee_id INT
)
BEGIN
    SELECT 
        e.employee_id,
        e.employee_code AS code,
        e.employee_name AS name,
        d.departmentname AS dept,
        e.department_id,
        r.role AS role_name
    FROM employee e
    LEFT JOIN department d 
        ON e.department_id = d.department_id
    LEFT JOIN app_role r 
        ON e.role_id = r.role_id
    WHERE 
        e.employee_id != p_exclude_employee_id
        AND e.active = 1
        AND (
            p_search_term IS NULL 
            OR p_search_term = ''
            OR e.employee_name LIKE CONCAT('%', p_search_term, '%')
            OR e.employee_code LIKE CONCAT('%', p_search_term, '%')
        )
        AND (
            p_department_id IS NULL
            OR p_department_id = 0
            OR e.department_id = p_department_id
        )
    ORDER BY e.employee_name ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_roles` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_roles`()
BEGIN
    SELECT role_id, role FROM app_role ORDER BY role ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_role_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_role_policy`(
    IN p_role_id INT
)
BEGIN
    SELECT 
        lpr.*,
        lp.policy_name,
        lp.policy_year
    FROM leave_policy_role lpr
    JOIN leave_policy lp ON lpr.leave_policy_id = lp.leave_policy_id
    WHERE lpr.role_id = p_role_id AND lpr.active = 1;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_role_privileges` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_role_privileges`(
    IN p_role_id INT
)
BEGIN
    SELECT 
        rp.app_role_privilege_id,
        rp.role_id,
        rp.settings_id,
        rp.app_privilege_value,
        s.settings_key
    FROM app_role_privilege rp
    JOIN settings s ON rp.settings_id = s.settings_id
    WHERE rp.role_id = p_role_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_setting` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_setting`(
    IN p_setting_key VARCHAR(100)
)
BEGIN
    SELECT settings_key, settings_value 
    FROM settings 
    WHERE settings_key = p_setting_key;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_subordinate_leave_requests` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_subordinate_leave_requests`(
    IN p_manager_id INT,
    IN p_status VARCHAR(50) 
)
BEGIN
    SELECT 
        lr.*,
        e.employee_name,
        e.employee_code,
        r.role_name as employee_role,
        des.designation_name as employee_designation
    FROM leave_requests lr
    JOIN employee e ON lr.employee_id = e.employee_id
    LEFT JOIN role r ON e.role_id = r.role_id
    LEFT JOIN designation des ON e.designation_id = des.designation_id
    WHERE (e.reporting_manager_id = p_manager_id OR p_manager_id IS NULL) 
      AND (p_status IS NULL OR p_status = '' OR lr.status = p_status)
    ORDER BY lr.applied_on DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_user_auth_details` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_get_user_auth_details`(
    IN p_email VARCHAR(255)
)
BEGIN
    SELECT 
        ua.user_accounts_id,
        ua.user_display_name,
        ua.user_password,
        ua.email,
        COALESCE(e.role_id, ua.role_id) AS role_id,
        ua.employee_id,
        ua.active AS user_active,
        r.role AS role_name
    FROM user_accounts ua
    LEFT JOIN employee e
        ON ua.employee_id = e.employee_id
    LEFT JOIN app_role r
        ON r.role_id = COALESCE(e.role_id, ua.role_id)
    WHERE ua.email = p_email
      AND ua.active = 1
      AND (ua.employee_id IS NULL OR e.active = 1);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_handle_adjustment_approval` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_handle_adjustment_approval`(
    IN p_adjustment_id INT,
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_date DATE;
    DECLARE v_type ENUM('Regularization', 'OnDuty');
    DECLARE v_punch_time TIME;
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_approved_count INT;
    
    -- 1. Get adjustment details
    SELECT employee_id, date, type, punch_time 
    INTO v_emp_id, v_date, v_type, v_punch_time 
    FROM attendance_adjustments 
    WHERE adjustment_id = p_adjustment_id;
    
    SET v_month = MONTH(v_date);
    SET v_year = YEAR(v_date);
    
    -- 2. Update status to Approved
    UPDATE attendance_adjustments 
    SET status = 'Approved', 
        approved_by_id = p_approver_id, 
        approved_on = NOW(),
        remarks = CONCAT(COALESCE(remarks, ''), ' | Final Approval: ', p_remarks)
    WHERE adjustment_id = p_adjustment_id;
    
    -- 3. Apply changes to attendance table based on type
    IF v_type = 'Regularization' THEN
        -- Count previous approved regularizations this month
        SELECT COUNT(*) INTO v_approved_count 
        FROM attendance_adjustments 
        WHERE employee_id = v_emp_id 
          AND MONTH(date) = v_month 
          AND YEAR(date) = v_year 
          AND status = 'Approved'
          AND type = 'Regularization'
          AND adjustment_id != p_adjustment_id;
          
        IF v_approved_count < 3 THEN
            UPDATE attendance_daily 
            SET regularization_shift_type = 'FullDay', deduction_days = 0.00, status = 'Present'
            WHERE employee_id = v_emp_id AND date = v_date;
        ELSE
            UPDATE attendance_daily 
            SET regularization_shift_type = 'FullDay', deduction_days = 0.50, status = 'Present'
            WHERE employee_id = v_emp_id AND date = v_date;
        END IF;
    
    ELSEIF v_type = 'OnDuty' THEN
        -- Mark as Present for both shifts
        INSERT INTO attendance_daily (employee_id, date, status, first_in_time, last_out_time, onduty_shift_type, deduction_days)
        VALUES (v_emp_id, v_date, 'Present', '09:00:00', '17:00:00', 'FullDay', 0.00)
        ON DUPLICATE KEY UPDATE 
            status = 'Present', first_in_time = '09:00:00', last_out_time = '17:00:00', onduty_shift_type = 'FullDay', deduction_days = 0.00;
    END IF;
    
    SELECT 'Success' as result;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_handle_regularization_approval` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_handle_regularization_approval`(
    IN p_adjustment_id INT,
    IN p_approver_id INT,
    IN p_remarks TEXT
)
BEGIN
    DECLARE v_emp_id INT;
    DECLARE v_date DATE;
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_approved_count INT;
    
    
    SELECT employee_id, date INTO v_emp_id, v_date FROM attendance_adjustments WHERE adjustment_id = p_adjustment_id;
    SET v_month = MONTH(v_date);
    SET v_year = YEAR(v_date);
    
    
    SELECT COUNT(*) INTO v_approved_count 
    FROM attendance_adjustments 
    WHERE employee_id = v_emp_id 
      AND MONTH(date) = v_month 
      AND YEAR(date) = v_year 
      AND status = 'Approved'
      AND type = 'Regularization';
      
    
    UPDATE attendance_adjustments 
    SET status = 'Approved', 
        approved_by_id = p_approver_id, 
        approved_on = NOW(),
        remarks = p_remarks
    WHERE adjustment_id = p_adjustment_id;
    
    
    IF v_approved_count < 3 THEN
        UPDATE attendance 
        SET is_regularized = 1, deduction_days = 0.00 
        WHERE employee_id = v_emp_id AND date = v_date;
    ELSE
        UPDATE attendance 
        SET is_regularized = 1, deduction_days = 0.50 
        WHERE employee_id = v_emp_id AND date = v_date;
    END IF;
    
    SELECT v_approved_count + 1 AS monthly_approved_count;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_process_attendance` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_process_attendance`(IN p_date DATE)
BEGIN

    DECLARE done       INT DEFAULT FALSE;
    DECLARE v_emp_id   INT;

    DECLARE v_first_in    TIME    DEFAULT NULL;
    DECLARE v_last_out    TIME    DEFAULT NULL;
    DECLARE v_worked_mins INT     DEFAULT 0;

    DECLARE v_holiday_type VARCHAR(50)  DEFAULT NULL;
    DECLARE v_is_worked    TINYINT      DEFAULT 0;
    DECLARE v_leave_type   VARCHAR(100) DEFAULT NULL;
    DECLARE v_leave_half   VARCHAR(20)  DEFAULT 'FullDay';
    DECLARE v_is_paid      TINYINT      DEFAULT 1;

    DECLARE v_emp_shift_id INT DEFAULT -1;

    DECLARE v_fd_start       TIME DEFAULT '09:00:00';
    DECLARE v_fd_end         TIME DEFAULT '16:30:00';
    DECLARE v_fd_start_grace INT  DEFAULT 15;
    DECLARE v_fd_end_grace   INT  DEFAULT 25;

    DECLARE v_fh_start       TIME DEFAULT '09:00:00';
    DECLARE v_fh_end         TIME DEFAULT '13:00:00';
    DECLARE v_fh_start_grace INT  DEFAULT 15;
    DECLARE v_fh_end_grace   INT  DEFAULT 5;

    DECLARE v_sh_start       TIME DEFAULT '13:30:00';
    DECLARE v_sh_end         TIME DEFAULT '16:30:00';
    DECLARE v_sh_start_grace INT  DEFAULT 0;
    DECLARE v_sh_end_grace   INT  DEFAULT 5;

    DECLARE v_fd_grace_in  TIME DEFAULT NULL;
    DECLARE v_fd_grace_out TIME DEFAULT NULL;
    DECLARE v_fh_grace_in  TIME DEFAULT NULL;
    DECLARE v_fh_grace_out TIME DEFAULT NULL;
    DECLARE v_sh_grace_in  TIME DEFAULT NULL;
    DECLARE v_sh_grace_out TIME DEFAULT NULL;

    DECLARE v_no_punch_out       TINYINT      DEFAULT 0;
    DECLARE v_shift_type         VARCHAR(20)  DEFAULT 'FullDay';
    DECLARE v_deduction          DECIMAL(3,2) DEFAULT 1.00;
    -- Punch-only deduction captured before any leave adjustments;
    -- used exclusively to derive status so leave never influences Present/Absent.
    DECLARE v_punch_deduction    DECIMAL(3,2) DEFAULT 1.00;
    DECLARE v_is_late            TINYINT      DEFAULT 0;
    DECLARE v_late_minutes       INT          DEFAULT 0;
    DECLARE v_is_early           TINYINT      DEFAULT 0;
    DECLARE v_early_minutes      INT          DEFAULT 0;
    DECLARE v_overtime_mins      INT          DEFAULT 0;

    DECLARE emp_cursor CURSOR FOR
        SELECT employee_id FROM employee WHERE active = 1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN emp_cursor;

    SET SQL_SAFE_UPDATES = 0;
    SET SESSION MAX_EXECUTION_TIME = 120000;

    read_loop: LOOP

        FETCH emp_cursor INTO v_emp_id;
        IF done THEN LEAVE read_loop; END IF;

        -- ── Reset all variables ────────────────────────────────────────────────
        SET done              = FALSE;
        SET v_first_in        = NULL;
        SET v_last_out        = NULL;
        SET v_worked_mins     = 0;
        SET v_holiday_type    = NULL;
        SET v_is_worked       = 0;
        SET v_leave_type      = NULL;
        SET v_leave_half      = 'FullDay';
        SET v_is_paid         = 1;
        SET v_emp_shift_id    = -1;
        SET v_fd_start        = '09:00:00';
        SET v_fd_end          = '16:30:00';
        SET v_fd_start_grace  = 15;
        SET v_fd_end_grace    = 25;
        SET v_fh_start        = '09:00:00';
        SET v_fh_end          = '13:00:00';
        SET v_fh_start_grace  = 15;
        SET v_fh_end_grace    = 5;
        SET v_sh_start        = '13:30:00';
        SET v_sh_end          = '16:30:00';
        SET v_sh_start_grace  = 0;
        SET v_sh_end_grace    = 5;
        SET v_no_punch_out    = 0;
        SET v_shift_type      = 'FullDay';
        SET v_deduction       = 1.00;
        SET v_punch_deduction = 1.00;
        SET v_is_late         = 0;
        SET v_late_minutes    = 0;
        SET v_is_early        = 0;
        SET v_early_minutes   = 0;
        SET v_overtime_mins   = 0;

        -- ── Skip already-regularized or on-duty rows ───────────────────────────
        BEGIN
            DECLARE v_reg_check VARCHAR(20) DEFAULT NULL;
            DECLARE v_od_check VARCHAR(20) DEFAULT NULL;
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT regularization_shift_type, onduty_shift_type 
            INTO v_reg_check, v_od_check
            FROM   attendance_daily
            WHERE  employee_id = v_emp_id
              AND  date        = p_date
            LIMIT  1;

            IF v_reg_check IS NOT NULL OR v_od_check IS NOT NULL THEN
                ITERATE read_loop;
            END IF;
        END;

        -- ── Shift resolution (Query shift_master directly) ────────────────────
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT CASE
                WHEN EXISTS (
                    SELECT 1 FROM shift_master
                    WHERE is_active   = 1
                      AND start_date <= p_date
                      AND (end_date IS NULL OR end_date >= p_date)
                      AND employee_id = v_emp_id
                ) THEN v_emp_id
                ELSE -1
            END INTO v_emp_shift_id;
        END;

        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
            SELECT start_time, end_time, start_grace_mins, end_grace_mins
            INTO   v_fd_start, v_fd_end, v_fd_start_grace, v_fd_end_grace
            FROM   shift_master
            WHERE  is_active   = 1
              AND  start_date <= p_date
              AND  (end_date IS NULL OR end_date >= p_date)
              AND  employee_id = v_emp_shift_id
              AND  shift_type  = 'FullDay'
            LIMIT  1;
        END;

        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
            SELECT start_time, end_time, start_grace_mins, end_grace_mins
            INTO   v_fh_start, v_fh_end, v_fh_start_grace, v_fh_end_grace
            FROM   shift_master
            WHERE  is_active   = 1
              AND  start_date <= p_date
              AND  (end_date IS NULL OR end_date >= p_date)
              AND  employee_id = v_emp_shift_id
              AND  shift_type  = 'FirstHalf'
            LIMIT  1;
        END;

        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
            SELECT start_time, end_time, start_grace_mins, end_grace_mins
            INTO   v_sh_start, v_sh_end, v_sh_start_grace, v_sh_end_grace
            FROM   shift_master
            WHERE  is_active   = 1
              AND  start_date <= p_date
              AND  (end_date IS NULL OR end_date >= p_date)
              AND  employee_id = v_emp_shift_id
              AND  shift_type  = 'SecondHalf'
            LIMIT  1;
        END;

        -- Derive grace limits
        SET v_fd_grace_in  = ADDTIME(v_fd_start, SEC_TO_TIME(v_fd_start_grace * 60));
        SET v_fd_grace_out = SUBTIME(v_fd_end, SEC_TO_TIME(v_fd_end_grace * 60));
        SET v_fh_grace_in  = ADDTIME(v_fh_start, SEC_TO_TIME(v_fh_start_grace * 60));
        SET v_fh_grace_out = SUBTIME(v_fh_end, SEC_TO_TIME(v_fh_end_grace * 60));
        SET v_sh_grace_in  = ADDTIME(v_sh_start, SEC_TO_TIME(v_sh_start_grace * 60));
        SET v_sh_grace_out = SUBTIME(v_sh_end, SEC_TO_TIME(v_sh_end_grace * 60));

        -- ── Punch data ────────────────────────────────────────────────────────
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT
                MIN(TIME(l.punch_time)),
                MAX(TIME(l.punch_time))
            INTO
                v_first_in,
                v_last_out
            FROM attendance_punches_detail l
            JOIN employee e
                ON TRIM(e.employee_code) = TRIM(l.employee_code)
            WHERE e.employee_id = v_emp_id
              AND l.punch_time >= CONCAT(p_date, ' 00:00:00')
              AND l.punch_time <  CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00');
        END;

        -- Calculate worked minutes
        IF v_first_in IS NOT NULL AND v_last_out IS NOT NULL AND v_first_in != v_last_out THEN
            SET v_worked_mins = TIMESTAMPDIFF(MINUTE, 
                                    TIMESTAMP(p_date, v_first_in), 
                                    TIMESTAMP(p_date, v_last_out));
        ELSE
            SET v_worked_mins = 0;
        END IF;

        -- ── Holiday Check ──────────────────────────────────────────────────────
        SELECT holiday_type 
        INTO v_holiday_type
        FROM holiday_master
        WHERE p_date BETWEEN holiday_start_date AND holiday_end_date
          AND is_active = 1
          AND (employee_id IS NULL OR employee_id = 0 OR employee_id = v_emp_id)
        ORDER BY holiday_id DESC
        LIMIT 1;


        -- ── Skip check-in logic if Holiday / Weekend (No Punches required) ──────
        IF v_holiday_type IS NOT NULL AND v_first_in IS NULL THEN
            
            INSERT INTO attendance_daily (
                employee_id, date, status, 
                shift_type, worked_mins, 
                deduction_days, 
                created_on
            )
            VALUES (
                v_emp_id, p_date, v_holiday_type, 
                'FullDay', 0, 0.00, NOW()
            )
            ON DUPLICATE KEY UPDATE
                status         = v_holiday_type,
                shift_type     = 'FullDay',
                worked_mins    = 0,
                deduction_days = 0.00;


            ITERATE read_loop;

        END IF;

        -- ── Leave check ────────────────────────────────────────────────────────
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

            SELECT
                lr.leave_type,
                COALESCE(lr.leave_half_type, 'FullDay'),
                lr.is_paid
            INTO
                v_leave_type,
                v_leave_half,
                v_is_paid
            FROM leave_requests lr
            WHERE lr.employee_id = v_emp_id
              AND lr.status      = 'Approved'
              AND p_date BETWEEN lr.start_date AND lr.end_date
            ORDER BY lr.leave_request_id DESC
            LIMIT 1;
        END;

        -- ── No punch-in → Absent ───────────────────────────────────────────────
        IF v_first_in IS NULL THEN

            INSERT INTO attendance_daily (
                employee_id, date, status,
                shift_type, worked_mins,
                deduction_days,
                is_leave, leave_shift_type,
                regularization_shift_type,
                onduty_shift_type,
                created_on
            )
            VALUES (
                v_emp_id, p_date,
                'Absent',
                'FullDay',
                0,
                IF(v_leave_type IS NOT NULL, IF(v_is_paid = 1, 0, 1), 1),
                IF(v_leave_type IS NOT NULL, 1, 0),
                CASE
                    WHEN v_leave_type IS NULL        THEN NULL
                    WHEN v_leave_half = 'FirstHalf'  THEN 'FirstHalf'
                    WHEN v_leave_half = 'SecondHalf' THEN 'SecondHalf'
                    ELSE 'FullDay'
                END,
                NULL, NULL,
                NOW()
            )
            ON DUPLICATE KEY UPDATE
                status                    = 'Absent',
                shift_type                = 'FullDay',
                worked_mins               = 0,
                deduction_days            = VALUES(deduction_days),
                is_leave                  = VALUES(is_leave),
                leave_shift_type          = VALUES(leave_shift_type),
                regularization_shift_type = NULL,
                onduty_shift_type         = NULL;


            ITERATE read_loop;

        END IF;

        -- ── Single punch → Incomplete punch → 1.0 Deduction ───────────────────
        IF v_first_in = v_last_out THEN
            SET v_deduction = 1.00;
            SET v_no_punch_out = 1;
            SET v_shift_type = 'FullDay';
        ELSE
            SET v_no_punch_out = 0;

            -- ── Shift classification ───────────────────────────────────────────
            IF v_first_in <= v_fd_grace_in
                AND v_last_out >= v_fd_grace_out THEN
                SET v_shift_type = 'FullDay';
                SET v_deduction  = 0.00;

            ELSEIF v_first_in  <= v_fh_grace_in
                AND v_last_out  >= v_fh_grace_out
                AND v_last_out   < v_fd_grace_out THEN
                SET v_shift_type = 'FirstHalf';
                SET v_deduction  = 0.50;

            ELSEIF v_first_in  >  v_fh_grace_in
                AND v_first_in  <= v_sh_grace_in
                AND v_last_out  >= v_sh_grace_out THEN
                SET v_shift_type = 'SecondHalf';
                SET v_deduction  = 0.50;

            ELSE
                IF v_last_out <= v_fh_end THEN
                    SET v_shift_type = 'FirstHalf';
                    SET v_deduction  = 0.50;
                ELSEIF v_first_in >= v_sh_start THEN
                    SET v_shift_type = 'SecondHalf';
                    SET v_deduction  = 0.50;
                ELSE
                    SET v_shift_type = 'FullDay';
                    SET v_deduction  = 0.00;
                END IF;
            END IF;

            -- ── Late-in detection ──────────────────────────────────────────────
            IF v_shift_type IN ('FullDay', 'FirstHalf') THEN
                IF v_first_in > v_fd_grace_in THEN
                    SET v_is_late      = 1;
                    SET v_late_minutes = TIMESTAMPDIFF(MINUTE, v_fd_start, v_first_in);
                END IF;
            END IF;

            IF v_shift_type = 'SecondHalf' THEN
                IF v_first_in > v_sh_grace_in THEN
                    SET v_is_late      = 1;
                    SET v_late_minutes = TIMESTAMPDIFF(MINUTE, v_sh_start, v_first_in);
                END IF;
            END IF;

            -- ── Early-leaving detection ────────────────────────────────────────
            IF v_shift_type = 'FullDay' THEN
                IF v_last_out < v_fd_grace_out THEN
                    SET v_is_early      = 1;
                    SET v_early_minutes = TIMESTAMPDIFF(MINUTE, v_last_out, v_fd_end);
                END IF;
            END IF;

            IF v_shift_type = 'FirstHalf' THEN
                IF v_last_out > v_fh_end AND v_last_out < v_fd_grace_out THEN
                    SET v_is_early      = 1;
                    SET v_early_minutes = TIMESTAMPDIFF(MINUTE, v_last_out, v_fd_end);
                ELSEIF v_last_out <= v_fh_end AND v_last_out < v_fh_grace_out THEN
                    SET v_is_early      = 1;
                    SET v_early_minutes = TIMESTAMPDIFF(MINUTE, v_last_out, v_fh_end);
                END IF;
            END IF;

            IF v_shift_type = 'SecondHalf' THEN
                IF v_last_out < v_sh_grace_out THEN
                    SET v_is_early      = 1;
                    SET v_early_minutes = TIMESTAMPDIFF(MINUTE, v_last_out, v_sh_end);
                END IF;
            END IF;

            -- ── Deduction penalties ────────────────────────────────────────────
            IF v_shift_type = 'FullDay' THEN
                IF v_is_late = 1 AND v_is_early = 1 THEN
                    SET v_deduction = 1.00;
                ELSEIF v_is_late = 1 OR v_is_early = 1 THEN
                    SET v_deduction = v_deduction + 0.50;
                END IF;
            END IF;

            IF v_shift_type = 'FirstHalf' THEN
                IF v_is_late = 1 OR v_is_early = 1 THEN
                    IF v_last_out <= v_fh_end THEN
                        SET v_deduction = 1.00;
                    END IF;
                END IF;
            END IF;

            IF v_shift_type = 'SecondHalf' THEN
                IF v_is_late = 1 OR v_is_early = 1 THEN
                    SET v_deduction = 1.00;
                END IF;
            END IF;
        END IF;

        -- If weekend / holiday is worked, mark it as Present and v_deduction = 0
        IF v_holiday_type IS NOT NULL THEN
            SET v_deduction = 0.00;
            SET v_is_worked = 1;
            SET v_shift_type = 'FullDay';
        END IF;

        IF v_deduction > 1.0 THEN SET v_deduction = 1.0; END IF;

        -- ── Snapshot punch-only deduction for status derivation ───────────────
        SET v_punch_deduction = v_deduction;

        -- ── Half-day leave adjustments (deduction cap only, never touch status) ──
        IF v_leave_type IS NOT NULL AND v_leave_half = 'FirstHalf' THEN
            IF v_is_paid = 1 THEN
                SET v_deduction    = IF(v_deduction > 0.5, 0.5, v_deduction);
            ELSE
                SET v_deduction    = IF(v_deduction < 0.5, 0.5, v_deduction);
            END IF;
            SET v_is_late      = 0;
            SET v_late_minutes = 0;
        END IF;

        IF v_leave_type IS NOT NULL AND v_leave_half = 'SecondHalf' THEN
            IF v_is_paid = 1 THEN
                SET v_deduction     = IF(v_deduction > 0.5, 0.5, v_deduction);
            ELSE
                SET v_deduction     = IF(v_deduction < 0.5, 0.5, v_deduction);
            END IF;
            SET v_is_early      = 0;
            SET v_early_minutes = 0;
        END IF;

        -- ── Full-day leave: deduction = 0 (employee is covered) ───────────────
        IF v_leave_type IS NOT NULL AND v_leave_half = 'FullDay' THEN
            SET v_deduction = IF(v_is_paid = 1, 0, 1.0);
        END IF;

        -- ── Overtime: only clean FullDay (no late, no early) ──────────────────
        IF v_deduction = 0.00 AND v_worked_mins > 480 AND v_is_worked = 0 THEN
            SET v_overtime_mins = v_worked_mins - 480;
        END IF;

        -- Write record
        INSERT INTO attendance_daily (
            employee_id, date, first_in_time, last_out_time, worked_mins,
            shift_type, status,
            is_late, late_minutes,
            is_early_leaving, early_minutes,
            overtime_minutes, deduction_days,
            is_worked_on_holiday,
            is_leave, leave_shift_type,
            created_on
        )
        VALUES (
            v_emp_id, p_date, v_first_in, v_last_out, v_worked_mins,
            v_shift_type,
            IF(v_holiday_type IS NOT NULL, v_holiday_type, IF(v_punch_deduction = 1.00, 'Absent', 'Present')),
            v_is_late, v_late_minutes,
            v_is_early, v_early_minutes,
            v_overtime_mins, v_deduction,
            v_is_worked,
            IF(v_leave_type IS NOT NULL, 1, 0),
            IF(v_leave_type IS NOT NULL, v_leave_half, NULL),
            NOW()
        )
        ON DUPLICATE KEY UPDATE
            first_in_time             = VALUES(first_in_time),
            last_out_time             = VALUES(last_out_time),
            worked_mins               = VALUES(worked_mins),
            shift_type                = VALUES(shift_type),
            status                    = VALUES(status),
            is_late                   = VALUES(is_late),
            late_minutes              = VALUES(late_minutes),
            is_early_leaving          = VALUES(is_early_leaving),
            early_minutes             = VALUES(early_minutes),
            overtime_minutes          = VALUES(overtime_minutes),
            deduction_days            = VALUES(deduction_days),
            is_worked_on_holiday      = VALUES(is_worked_on_holiday),
            is_leave                  = VALUES(is_leave),
            leave_shift_type          = VALUES(leave_shift_type),
            regularization_shift_type = regularization_shift_type,
            onduty_shift_type         = onduty_shift_type;


        -- ── Mark punches processed ─────────────────────────────────────────────
        UPDATE attendance_punches_detail l
        JOIN   employee e
            ON TRIM(e.employee_code) = TRIM(l.employee_code)
        SET    l.processed_flag = 1
        WHERE  e.employee_id    = v_emp_id
          AND  l.punch_time    >= CONCAT(p_date, ' 00:00:00')
          AND  l.punch_time     < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
          AND  l.processed_flag = 0;

    END LOOP read_loop;

    CLOSE emp_cursor;

    -- 1. Identify and log punches for inactive employees
    INSERT INTO attendance_invalid_log (employee_id, punch_time, reason)
    SELECT l.employee_code, l.punch_time, 'Inactive employee'
    FROM attendance_punches_detail l
    JOIN employee e ON TRIM(e.employee_code) = TRIM(l.employee_code)
    WHERE l.punch_time >= CONCAT(p_date, ' 00:00:00')
      AND l.punch_time < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
      AND l.processed_flag = 0
      AND e.active = 0;

    -- 2. Identify and log punches for unknown/unmatched employee codes
    INSERT INTO attendance_invalid_log (employee_id, punch_time, reason)
    SELECT l.employee_code, l.punch_time, 'Unknown employee code'
    FROM attendance_punches_detail l
    LEFT JOIN employee e ON TRIM(e.employee_code) = TRIM(l.employee_code)
    WHERE l.punch_time >= CONCAT(p_date, ' 00:00:00')
      AND l.punch_time < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
      AND l.processed_flag = 0
      AND e.employee_id IS NULL;

    -- 3. Mark all remaining unprocessed logs for this date as processed_flag = 2
    UPDATE attendance_punches_detail l
    SET l.processed_flag = 2
    WHERE l.punch_time >= CONCAT(p_date, ' 00:00:00')
      AND l.punch_time < CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00')
      AND l.processed_flag = 0;

    SET SESSION MAX_EXECUTION_TIME = 0;
    SET SQL_SAFE_UPDATES = 1;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_process_attendance_logs` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_process_attendance_logs`(
    IN p_date DATE
)
BEGIN
    DECLARE v_grace_in TIME;
    DECLARE v_early_out TIME;
    DECLARE v_deduction_amount DECIMAL(3,2);
    
    -- Load settings
    SELECT setting_value INTO v_grace_in FROM attendance_settings WHERE setting_key = 'grace_in_time';
    SELECT setting_value INTO v_early_out FROM attendance_settings WHERE setting_key = 'early_out_threshold';
    SELECT CAST(setting_value AS DECIMAL(3,2)) INTO v_deduction_amount FROM attendance_settings WHERE setting_key = 'deduction_amount';

    -- 1. Process Punch-Ins
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_late, deduction_days)
    SELECT 
        adl.employee_id, 
        adl.date, 
        'Present', 
        'Biometric', 
        'PunchIn', 
        'Full Day', 
        MIN(adl.time),
        IF(MIN(adl.time) > v_grace_in, 1, 0),
        IF(MIN(adl.time) > v_grace_in, v_deduction_amount, 0.00)
    FROM attendance_detail_log adl
    INNER JOIN employee e ON adl.employee_id = e.employee_id
    WHERE adl.date = p_date AND e.active = 1
    GROUP BY adl.employee_id, adl.date
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_late = VALUES(is_late),
        deduction_days = VALUES(deduction_days),
        status = 'Present';

    -- 2. Process Punch-Outs
    INSERT INTO attendance (employee_id, date, status, punch_type, type, shift_type, punch_time, is_early_leaving, deduction_days)
    SELECT 
        adl.employee_id, 
        adl.date, 
        'Present', 
        'Biometric', 
        'PunchOut', 
        'Full Day', 
        MAX(adl.time),
        IF(MAX(adl.time) < v_early_out, 1, 0),
        IF(MAX(adl.time) < v_early_out, v_deduction_amount, 0.00)
    FROM attendance_detail_log adl
    INNER JOIN employee e ON adl.employee_id = e.employee_id
    WHERE adl.date = p_date AND e.active = 1
    GROUP BY adl.employee_id, adl.date
    HAVING COUNT(*) > 1
    ON DUPLICATE KEY UPDATE 
        punch_time = VALUES(punch_time),
        is_early_leaving = VALUES(is_early_leaving),
        deduction_days = GREATEST(deduction_days, VALUES(deduction_days)),
        status = 'Present';
        
    SELECT ROW_COUNT() AS processed_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_process_attendance_old` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_process_attendance_old`(
    IN p_process_date DATE
)
BEGIN
    DECLARE v_employee_id       VARCHAR(45);
    DECLARE v_punch_time        DATETIME;
    DECLARE v_log_id            INT;
    DECLARE v_shift_id          INT;
    DECLARE v_shift_type        ENUM('FullDay','FirstHalf','SecondHalf');
    DECLARE v_start_time        TIME;
    DECLARE v_end_time          TIME;
    DECLARE v_start_grace       INT;
    DECLARE v_end_grace         INT;
    DECLARE v_half_start        TIME;
    DECLARE v_half_end          TIME;
    DECLARE v_half_grace_end    INT;
    DECLARE v_half_grace_start  INT;
    DECLARE v_punch_date        DATE;
    DECLARE v_punch_time_only   TIME;
    DECLARE v_is_late           TINYINT DEFAULT 0;
    DECLARE v_is_early          TINYINT DEFAULT 0;
    DECLARE v_type              ENUM('PunchIn','PunchOut');
    DECLARE v_shift_type_att    ENUM('First Half','Second Half','Full Day');
    DECLARE v_deduction         DECIMAL(3,2) DEFAULT 0.00;
    DECLARE v_attendance_id     INT;
    DECLARE v_existing_att_id   INT;
    DECLARE v_existing_punch    TIME;
    DECLARE v_punchin_att_id    INT;
    DECLARE v_punchin_time      TIME;
    DECLARE v_detail_exists     INT DEFAULT 0;
    DECLARE v_not_found         INT DEFAULT 0;

    DECLARE cur_punches CURSOR FOR
        SELECT log_id, employee_id, punch_time
        FROM attendance_detail_log
        WHERE DATE(punch_time) = p_process_date
          AND processed_flag IN (0, 2)
        ORDER BY employee_id, punch_time;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = 1;

    OPEN cur_punches;

    punch_loop: LOOP

        SET v_not_found = 0;
        FETCH cur_punches INTO v_log_id, v_employee_id, v_punch_time;
        IF v_not_found = 1 THEN LEAVE punch_loop; END IF;

        SET v_punch_date        = DATE(v_punch_time);
        SET v_punch_time_only   = TIME(v_punch_time);
        SET v_is_late           = 0;
        SET v_is_early          = 0;
        SET v_deduction         = 0.00;
        SET v_existing_att_id   = NULL;
        SET v_existing_punch    = NULL;
        SET v_punchin_att_id    = NULL;
        SET v_punchin_time      = NULL;
        SET v_shift_id          = NULL;
        SET v_half_end          = NULL;
        SET v_half_start        = NULL;
        SET v_half_grace_end    = 0;
        SET v_half_grace_start  = 0;

        
        
        
        SET v_not_found = 0;
        SELECT shift_id, shift_type, start_time, end_time,
               start_grace_mins, end_grace_mins
        INTO   v_shift_id, v_shift_type, v_start_time, v_end_time,
               v_start_grace, v_end_grace
        FROM shift_master
        WHERE (employee_id = CAST(v_employee_id AS SIGNED) OR employee_id = -1)
          AND start_date  <= v_punch_date
          AND (end_date IS NULL OR end_date >= v_punch_date)
          AND is_active   = 1
          AND shift_type  = 'FullDay'
        ORDER BY CASE WHEN employee_id = CAST(v_employee_id AS SIGNED) THEN 0 ELSE 1 END
        LIMIT 1;
        SET v_not_found = 0;

        IF v_shift_id IS NULL THEN
            UPDATE attendance_detail_log
            SET processed_flag = 2
            WHERE log_id = v_log_id;
            ITERATE punch_loop;
        END IF;

        
        
        
        SET v_not_found = 0;
        SELECT end_time, end_grace_mins
        INTO   v_half_end, v_half_grace_end
        FROM shift_master
        WHERE (employee_id = CAST(v_employee_id AS SIGNED) OR employee_id = -1)
          AND start_date  <= v_punch_date
          AND (end_date IS NULL OR end_date >= v_punch_date)
          AND is_active   = 1
          AND shift_type  = 'FirstHalf'
        ORDER BY CASE WHEN employee_id = CAST(v_employee_id AS SIGNED) THEN 0 ELSE 1 END
        LIMIT 1;
        SET v_not_found = 0;

        
        
        
        SET v_not_found = 0;
        SELECT start_time, start_grace_mins
        INTO   v_half_start, v_half_grace_start
        FROM shift_master
        WHERE (employee_id = CAST(v_employee_id AS SIGNED) OR employee_id = -1)
          AND start_date  <= v_punch_date
          AND (end_date IS NULL OR end_date >= v_punch_date)
          AND is_active   = 1
          AND shift_type  = 'SecondHalf'
        ORDER BY CASE WHEN employee_id = CAST(v_employee_id AS SIGNED) THEN 0 ELSE 1 END
        LIMIT 1;
        SET v_not_found = 0;

        
        
        
        SET v_not_found     = 0;
        SET v_detail_exists = 0;
        SELECT COUNT(*) INTO v_detail_exists
        FROM attendance_detail
        WHERE employee_id = v_employee_id
          AND punch_time  = v_punch_time;
        SET v_not_found = 0;

        IF v_detail_exists > 0 THEN
            UPDATE attendance_detail_log
            SET processed_flag = 1
            WHERE log_id = v_log_id;
            ITERATE punch_loop;
        END IF;

        
        
        
        SET v_not_found      = 0;
        SET v_punchin_att_id = NULL;
        SET v_punchin_time   = NULL;
        SELECT attendance_id, punch_time
        INTO   v_punchin_att_id, v_punchin_time
        FROM attendance
        WHERE employee_id = CAST(v_employee_id AS SIGNED)
          AND date        = v_punch_date
          AND type        = 'PunchIn'
        LIMIT 1;
        SET v_not_found = 0;

        
        
        
        IF v_punchin_att_id IS NULL THEN

            SET v_type      = 'PunchIn';
            SET v_deduction = 0.00;
            SET v_is_late   = 0;

            IF v_punch_time_only > ADDTIME(v_start_time, SEC_TO_TIME(v_start_grace * 60)) THEN
                SET v_is_late   = 1;
                SET v_deduction = 0.50;
            END IF;

            INSERT INTO attendance (
                employee_id, date, status, punch_type, type,
                shift_type, punch_time, created_on,
                is_late, is_early_leaving, is_regularized, deduction_days
            ) VALUES (
                CAST(v_employee_id AS SIGNED), v_punch_date,
                'Present', 'Biometric', 'PunchIn',
                'Full Day',
                v_punch_time_only, NOW(),
                v_is_late, 0, 0, v_deduction
            );

            SET v_attendance_id = LAST_INSERT_ID();

        ELSE

            
            
            
            SET v_not_found       = 0;
            SET v_existing_att_id = NULL;
            SET v_existing_punch  = NULL;
            SELECT attendance_id, punch_time
            INTO   v_existing_att_id, v_existing_punch
            FROM attendance
            WHERE employee_id = CAST(v_employee_id AS SIGNED)
              AND date        = v_punch_date
              AND type        = 'PunchOut'
              AND punch_time  IS NOT NULL
            LIMIT 1;
            SET v_not_found = 0;

            IF v_existing_att_id IS NULL THEN

                IF v_half_start IS NOT NULL
                   AND v_punchin_time >= v_half_start THEN
                    SET v_shift_type_att = 'Second Half';

                ELSEIF v_half_end IS NOT NULL
                   AND v_punch_time_only <= ADDTIME(v_half_end, SEC_TO_TIME(v_half_grace_end * 60)) THEN
                    SET v_shift_type_att = 'First Half';

                ELSE
                    SET v_shift_type_att = 'Full Day';
                END IF;

                SET v_is_early  = 0;
                SET v_deduction = 0.00;
                IF v_shift_type_att = 'Full Day' AND
                   v_punch_time_only < SUBTIME(v_end_time, SEC_TO_TIME(v_end_grace * 60)) THEN
                    SET v_is_early  = 1;
                    SET v_deduction = 0.50;
                END IF;

                DELETE FROM attendance
                WHERE employee_id = CAST(v_employee_id AS SIGNED)
                  AND date        = v_punch_date
                  AND type        = 'PunchOut'
                  AND punch_time  IS NULL;

                INSERT INTO attendance (
                    employee_id, date, status, punch_type, type,
                    shift_type, punch_time, created_on,
                    is_late, is_early_leaving, is_regularized, deduction_days
                ) VALUES (
                    CAST(v_employee_id AS SIGNED), v_punch_date,
                    'Present', 'Biometric', 'PunchOut',
                    v_shift_type_att, v_punch_time_only, NOW(),
                    0, v_is_early, 0, v_deduction
                );

                SET v_attendance_id = LAST_INSERT_ID();

                UPDATE attendance
                SET
                    shift_type = v_shift_type_att,
                    is_late = CASE
                        WHEN v_shift_type_att = 'Second Half'
                             AND v_punchin_time > ADDTIME(
                                 v_half_start,
                                 SEC_TO_TIME(v_half_grace_start * 60))
                        THEN 1
                        ELSE is_late
                    END,
                    deduction_days = CASE
                        WHEN v_shift_type_att IN ('First Half', 'Second Half') THEN 0.50
                        ELSE deduction_days
                    END
                WHERE attendance_id = v_punchin_att_id;

                IF v_shift_type_att IN ('First Half', 'Second Half') THEN
                    UPDATE attendance
                    SET deduction_days = 0.00
                    WHERE attendance_id = v_attendance_id;
                END IF;

            ELSE

                
                
                
                IF v_punch_time_only > v_existing_punch THEN

                    IF v_half_start IS NOT NULL
                       AND v_punchin_time >= v_half_start THEN
                        SET v_shift_type_att = 'Second Half';

                    ELSEIF v_half_end IS NOT NULL
                       AND v_punch_time_only <= ADDTIME(v_half_end, SEC_TO_TIME(v_half_grace_end * 60)) THEN
                        SET v_shift_type_att = 'First Half';

                    ELSE
                        SET v_shift_type_att = 'Full Day';
                    END IF;

                    SET v_is_early  = 0;
                    SET v_deduction = 0.00;
                    IF v_shift_type_att = 'Full Day' AND
                       v_punch_time_only < SUBTIME(v_end_time, SEC_TO_TIME(v_end_grace * 60)) THEN
                        SET v_is_early  = 1;
                        SET v_deduction = 0.50;
                    END IF;

                    UPDATE attendance
                    SET punch_time       = v_punch_time_only,
                        shift_type       = v_shift_type_att,
                        is_early_leaving = v_is_early,
                        deduction_days   = v_deduction
                    WHERE attendance_id  = v_existing_att_id;

                    UPDATE attendance
                    SET
                        shift_type     = v_shift_type_att,
                        deduction_days = CASE
                            WHEN v_shift_type_att IN ('First Half', 'Second Half') THEN 0.50
                            ELSE deduction_days
                        END
                    WHERE attendance_id = v_punchin_att_id;

                    SET v_attendance_id = v_existing_att_id;

                ELSE
                    UPDATE attendance_detail_log
                    SET processed_flag = 1
                    WHERE log_id = v_log_id;
                    ITERATE punch_loop;
                END IF;

            END IF;
        END IF;

        
        
        
        INSERT INTO attendance_detail (
            attandance_id, employee_id, punch_time, created_on
        ) VALUES (
            v_attendance_id, v_employee_id, v_punch_time, NOW()
        );

        
        
        
        UPDATE attendance_detail_log
        SET processed_flag = 1
        WHERE log_id = v_log_id;

    END LOOP;

    CLOSE cur_punches;

    
    
    
    
    
    INSERT INTO attendance (
        employee_id, date, status, punch_type, type,
        shift_type, punch_time, created_on,
        is_late, is_early_leaving, is_regularized, deduction_days
    )
    SELECT
        a.employee_id,
        a.date,
        'Present',
        'Biometric',
        'PunchOut',
        'Full Day',
        NULL,
        NOW(),
        0,
        1,
        0,
        0.50
    FROM attendance a
    WHERE a.date       = p_process_date
      AND a.type       = 'PunchIn'
      AND a.shift_type = 'Full Day'
      AND NOT EXISTS (
          SELECT 1
          FROM (
              SELECT employee_id
              FROM attendance
              WHERE date = p_process_date
                AND type = 'PunchOut'
          ) AS po
          WHERE po.employee_id = a.employee_id
      );

    
    
    
    
    
    
    UPDATE attendance a
    INNER JOIN (
        SELECT employee_id
        FROM (
            SELECT employee_id
            FROM attendance
            WHERE date       = p_process_date
              AND type       = 'PunchOut'
              AND punch_time IS NULL
        ) AS missing_po
    ) AS mp ON mp.employee_id = a.employee_id
    SET a.deduction_days = 0.50
    WHERE a.date       = p_process_date
      AND a.type       = 'PunchIn'
      AND a.shift_type = 'Full Day';

    SELECT CONCAT('Attendance processed for date: ', p_process_date) AS result;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_process_attendance_range` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_process_attendance_range`(
    IN p_start DATE,
    IN p_end   DATE
)
BEGIN
    DECLARE v_date DATE;
    SET v_date = p_start;

    WHILE v_date <= p_end DO
        CALL sp_process_attendance(v_date);
        SET v_date = DATE_ADD(v_date, INTERVAL 1 DAY);
    END WHILE;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_process_attendance_v1` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_process_attendance_v1`(IN p_date DATE)
BEGIN

    DECLARE done     INT DEFAULT FALSE;
    DECLARE v_emp_id INT;

    DECLARE emp_cursor CURSOR FOR
        SELECT employee_id FROM employee WHERE active = 1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN emp_cursor;

    read_loop: LOOP

        FETCH emp_cursor INTO v_emp_id;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET @first_in  = NULL;
        SET @last_out  = NULL;

        SELECT 
            MIN(TIME(l.punch_time)),
            MAX(TIME(l.punch_time))
        INTO 
            @first_in,
            @last_out
        FROM attendance_detail_log l
        JOIN employee e 
            ON TRIM(e.employee_code) = TRIM(l.employee_code)
        WHERE e.employee_id = v_emp_id
        AND l.punch_time >= CONCAT(p_date, ' 00:00:00')
        AND l.punch_time <  CONCAT(DATE_ADD(p_date, INTERVAL 1 DAY), ' 00:00:00');

        
        SET done = FALSE;

        SET @holiday_type = NULL;

        SELECT holiday_type
        INTO @holiday_type
        FROM holiday_master
        WHERE p_date BETWEEN holiday_start_date AND holiday_end_date
        AND is_active = 1
        AND employee_id IN (v_emp_id, -1)
        ORDER BY CASE WHEN employee_id = v_emp_id THEN 1 ELSE 2 END
        LIMIT 1;

        
        SET done = FALSE;

        SET @is_worked = IF(@first_in IS NOT NULL, 1, 0);

        IF @holiday_type IS NOT NULL THEN

            INSERT INTO attendance_daily (
                employee_id, date, status,
                is_worked_on_holiday,
                first_in_time, last_out_time,
                worked_hours, deduction_days
            )
            VALUES (
                v_emp_id, p_date, @holiday_type,
                @is_worked,
                @first_in, @last_out,
                IF(@first_in IS NOT NULL AND @last_out IS NOT NULL,
                   ROUND(TIMESTAMPDIFF(
                        MINUTE,
                        TIMESTAMP(p_date, @first_in),
                        TIMESTAMP(p_date, @last_out)
                   ) / 60, 2),
                   0),
                0
            )
            ON DUPLICATE KEY UPDATE
                status               = @holiday_type,
                is_worked_on_holiday = @is_worked,
                first_in_time        = VALUES(first_in_time),
                last_out_time        = VALUES(last_out_time),
                worked_hours         = VALUES(worked_hours),
                deduction_days       = 0;

            ITERATE read_loop;

        END IF;

        IF @first_in IS NULL THEN

            INSERT INTO attendance_daily (
                employee_id, date, status, deduction_days
            )
            VALUES (
                v_emp_id, p_date, 'Absent', 1
            )
            ON DUPLICATE KEY UPDATE
                status         = 'Absent',
                deduction_days = 1;

            ITERATE read_loop;

        END IF;

        
        SET @fh_start    = NULL;
        SET @fh_end      = NULL;
        SET @sh_start    = NULL;
        SET @sh_end      = NULL;
        SET @start_grace = NULL;
        SET @end_grace   = NULL;

        SELECT 
            MAX(CASE WHEN shift_type = 'FirstHalf'  THEN start_time END),
            MAX(CASE WHEN shift_type = 'FirstHalf'  THEN end_time   END),
            MAX(CASE WHEN shift_type = 'SecondHalf' THEN start_time END),
            MAX(CASE WHEN shift_type = 'SecondHalf' THEN end_time   END),
            MAX(start_grace_mins),
            MAX(end_grace_mins)
        INTO 
            @fh_start, @fh_end,
            @sh_start, @sh_end,
            @start_grace, @end_grace
        FROM shift_master
        WHERE is_active = 1
        AND start_date <= p_date
        AND (end_date IS NULL OR end_date >= p_date)
        AND employee_id = (
            SELECT CASE 
                WHEN EXISTS (
                    SELECT 1 FROM shift_master
                    WHERE is_active = 1
                    AND start_date <= p_date
                    AND (end_date IS NULL OR end_date >= p_date)
                    AND employee_id = v_emp_id
                ) 
                THEN v_emp_id 
                ELSE -1 
            END
        );

        
        SET done = FALSE;

        
        IF @fh_start IS NULL THEN
            SET @fh_start    = '09:00:00';
            SET @fh_end      = '13:00:00';
            SET @sh_start    = '13:30:00';
            SET @sh_end      = '16:30:00';
            SET @start_grace = 15;
            SET @end_grace   = 5;
        END IF;

        SET @first_half = IF(
            @first_in <= ADDTIME(@fh_start, SEC_TO_TIME(@start_grace * 60))
            AND @last_out >= @fh_end, 1, 0
        );

        SET @second_half = IF(
            @first_in <= @sh_start
            AND @last_out >= SUBTIME(@sh_end, SEC_TO_TIME(@end_grace * 60)), 1, 0
        );

        IF @first_half = 1 AND @second_half = 1 THEN
            SET @shift_type = 'FullDay';
            SET @deduction  = 0;
        ELSEIF @first_half = 1 THEN
            SET @shift_type = 'FirstHalf';
            SET @deduction  = 0.5;
        ELSEIF @second_half = 1 THEN
            SET @shift_type = 'SecondHalf';
            SET @deduction  = 0.5;
        ELSE
            SET @shift_type = 'Absent';
            SET @deduction  = 1;
        END IF;

        SET @is_late      = 0;
        SET @late_minutes = 0;

        IF @shift_type IN ('FullDay', 'FirstHalf') THEN
            IF @first_in > ADDTIME(@fh_start, SEC_TO_TIME(@start_grace * 60)) THEN
                SET @is_late      = 1;
                SET @late_minutes = TIMESTAMPDIFF(
                    MINUTE,
                    TIMESTAMP(p_date, @fh_start),
                    TIMESTAMP(p_date, @first_in)
                );
            END IF;
        END IF;

        IF @shift_type = 'SecondHalf' THEN
            IF @first_in > ADDTIME(@sh_start, SEC_TO_TIME(@start_grace * 60)) THEN
                SET @is_late      = 1;
                SET @late_minutes = TIMESTAMPDIFF(
                    MINUTE,
                    TIMESTAMP(p_date, @sh_start),
                    TIMESTAMP(p_date, @first_in)
                );
            END IF;
        END IF;

        SET @is_early      = 0;
        SET @early_minutes = 0;

        IF @shift_type IN ('FullDay', 'SecondHalf') THEN
            IF @last_out < SUBTIME(@sh_end, SEC_TO_TIME(@end_grace * 60)) THEN
                SET @is_early      = 1;
                SET @early_minutes = TIMESTAMPDIFF(
                    MINUTE,
                    TIMESTAMP(p_date, @last_out),
                    TIMESTAMP(p_date, @sh_end)
                );
            END IF;
        END IF;

        IF @shift_type = 'FirstHalf' THEN
            IF @last_out < SUBTIME(@fh_end, SEC_TO_TIME(@end_grace * 60)) THEN
                SET @is_early      = 1;
                SET @early_minutes = TIMESTAMPDIFF(
                    MINUTE,
                    TIMESTAMP(p_date, @last_out),
                    TIMESTAMP(p_date, @fh_end)
                );
            END IF;
        END IF;

        IF @is_late = 1 AND @is_early = 1 THEN
            SET @deduction = @deduction + 0.5;
        END IF;

        INSERT INTO attendance_daily (
            employee_id, date,
            first_in_time, last_out_time,
            worked_hours,
            shift_type, status,
            is_late, late_minutes,
            is_early_leaving, early_minutes,
            deduction_days,
            is_worked_on_holiday
        )
        VALUES (
            v_emp_id, p_date,
            @first_in, @last_out,
            ROUND(TIMESTAMPDIFF(
                MINUTE,
                TIMESTAMP(p_date, @first_in),
                TIMESTAMP(p_date, @last_out)
            ) / 60, 2),
            @shift_type, 'Present',
            @is_late, @late_minutes,
            @is_early, @early_minutes,
            @deduction,
            0
        )
        ON DUPLICATE KEY UPDATE
            first_in_time        = VALUES(first_in_time),
            last_out_time        = VALUES(last_out_time),
            worked_hours         = VALUES(worked_hours),
            shift_type           = VALUES(shift_type),
            status               = VALUES(status),
            is_late              = VALUES(is_late),
            late_minutes         = VALUES(late_minutes),
            is_early_leaving     = VALUES(is_early_leaving),
            early_minutes        = VALUES(early_minutes),
            deduction_days       = VALUES(deduction_days),
            is_worked_on_holiday = VALUES(is_worked_on_holiday);

    END LOOP;

    CLOSE emp_cursor;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_request_attendance_adjustment` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_request_attendance_adjustment`(
    IN p_employee_id INT,
    IN p_type ENUM('Regularization', 'OnDuty'),
    IN p_date DATE,
    IN p_punch_time TIME,
    IN p_remarks TEXT,
    IN p_attachment_path VARCHAR(512)
)
BEGIN
    -- Validation for Regularization
    IF p_type = 'Regularization' THEN
        -- Check if regularization is actually needed
        -- Not needed if: Has both In and Out, both are Present, and neither is Late nor Early Leaving
        IF EXISTS (
            SELECT 1 FROM attendance 
            WHERE employee_id = p_employee_id AND date = p_date
            AND status = 'Present' 
            AND is_late = 0 AND is_early_leaving = 0
            GROUP BY employee_id, date
            HAVING COUNT(DISTINCT type) = 2
        ) THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Regularization is not required for this date as attendance is already complete and on-time.';
        END IF;

        -- Optional: Prevent future regularizations if needed
        IF p_date > CURRENT_DATE THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Regularization cannot be requested for future dates.';
        END IF;
    END IF;

    INSERT INTO attendance_adjustments (
        employee_id, type, date, punch_time, remarks, attachment_path, status, requested_on
    ) VALUES (
        p_employee_id, p_type, p_date, p_punch_time, p_remarks, p_attachment_path, 'Pending', NOW()
    );
    
    SELECT LAST_INSERT_ID() AS adjustment_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_request_leave_encashment` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_request_leave_encashment`(
    IN p_employee_id INT,
    IN p_leave_type VARCHAR(50),
    IN p_days DECIMAL(5,2)
)
BEGIN
    DECLARE v_basic_pay DECIMAL(15,2);
    DECLARE v_available_balance DECIMAL(5,2);
    DECLARE v_max_encash INT DEFAULT 10;
    DECLARE v_amount DECIMAL(15,2);

    
    SELECT basic_pay INTO v_basic_pay FROM employee WHERE employee_id = p_employee_id;

    IF v_basic_pay IS NULL OR v_basic_pay = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Basic pay not set for this employee. Please contact HR.';
    END IF;

    
    IF p_days > v_max_encash THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot encash more than 10 days of casual leave.';
    END IF;

    
    SET v_amount = ROUND((v_basic_pay / 26) * 0.5 * p_days, 2);

    INSERT INTO leave_encashments (employee_id, leave_type, days_to_encash, encashment_amount, status, requested_on)
    VALUES (p_employee_id, p_leave_type, p_days, v_amount, 'Pending', NOW());

    SELECT LAST_INSERT_ID() AS encashment_id, v_amount AS calculated_amount;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_reset_password_with_old` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_reset_password_with_old`(
    IN p_user_id INT,
    IN p_new_password VARCHAR(5000)
)
BEGIN
    UPDATE user_accounts 
    SET user_password = p_new_password,
        otp = NULL,
        otp_generated_on = NULL
    WHERE user_accounts_id = p_user_id;
    
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_reset_password_with_otp` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_reset_password_with_otp`(
    IN p_email VARCHAR(255),
    IN p_otp INT,
    IN p_new_password VARCHAR(5000)
)
BEGIN
    
    UPDATE user_accounts 
    SET user_password = p_new_password,
        otp = NULL,
        otp_generated_on = NULL
    WHERE email = p_email 
      AND otp = p_otp 
      AND otp_generated_on >= DATE_SUB(NOW(), INTERVAL 15 MINUTE);
    
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_run_payroll` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_run_payroll`(
    IN p_organization_id INT,
    IN p_period_id INT,
    IN p_prepared_by INT
)
BEGIN
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_status VARCHAR(30);
    DECLARE v_month INT;
    DECLARE v_year INT;
    DECLARE v_days_in_period INT;
    DECLARE done INT DEFAULT 0;
    DECLARE v_attendance_count INT;
    DECLARE v_temp_date DATE;
    DECLARE v_weekend_holiday_count INT;
    
    DECLARE v_emp_id INT;
    DECLARE v_struct_id INT;
    DECLARE v_basic_pay DECIMAL(15,2);
    DECLARE v_hra DECIMAL(15,2);
    DECLARE v_edu_allowance DECIMAL(15,2);
    DECLARE v_spec_allowance DECIMAL(15,2);
    DECLARE v_naac_allowance DECIMAL(15,2);
    DECLARE v_gross_salary DECIMAL(15,2);
    
    DECLARE v_lop_days DECIMAL(5,2);
    DECLARE v_lop_deduction DECIMAL(15,2);
    DECLARE v_payable_amount DECIMAL(15,2);
    
    -- Deductions variables
    DECLARE v_total_deduction DECIMAL(15,2);
    DECLARE v_net_salary DECIMAL(15,2);
    DECLARE v_epf_base DECIMAL(15,2);
    DECLARE v_epf_amount DECIMAL(15,2);
    DECLARE v_esi_base DECIMAL(15,2);
    DECLARE v_esi_amount DECIMAL(15,2);
    DECLARE v_pt_amount DECIMAL(15,2);
    DECLARE v_loan_deduction DECIMAL(15,2);
    DECLARE v_tds_amount DECIMAL(15,2);
    DECLARE v_bus_fee DECIMAL(15,2);
    DECLARE v_json_deductions JSON;
    DECLARE v_epf_rule_basis VARCHAR(50);
    DECLARE v_epf_rule_rate DECIMAL(10,4);
    DECLARE v_esi_rule_basis VARCHAR(50);
    DECLARE v_esi_rule_rate DECIMAL(10,4);
    
    DECLARE v_epf_rule_months VARCHAR(100);
    DECLARE v_epf_rule_multiplier INT;
    DECLARE v_esi_rule_months VARCHAR(100);
    DECLARE v_esi_rule_multiplier INT;
    DECLARE v_tds_rule_months VARCHAR(100);
    DECLARE v_tds_rule_multiplier INT;
    DECLARE v_pt_rule_months VARCHAR(100);
    DECLARE v_pt_rule_multiplier INT;
    DECLARE v_bus_fee_rule_months VARCHAR(100);
    DECLARE v_bus_fee_rule_multiplier INT;
    
    -- Cursor for employees
    DECLARE emp_cursor CURSOR FOR 
        SELECT e.employee_id 
        FROM employee e
        WHERE e.active = 1 AND (p_organization_id IS NULL OR e.organization_id = p_organization_id);
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    
    -- 1. Fetch Period Info
    SELECT start_date, end_date, status, month, year 
    INTO v_start_date, v_end_date, v_status, v_month, v_year
    FROM payroll_period
    WHERE period_id = p_period_id;
    
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payroll period not found';
    END IF;
    
    IF v_status IN ('completed', 'locked') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot run payroll on completed or locked periods';
    END IF;
    
    -- Set period status to processing
    UPDATE payroll_period 
    SET status = 'processing' 
    WHERE period_id = p_period_id;
    
    -- Clean up previous runs for this period
    DELETE FROM salary_disbursement WHERE period_id = p_period_id;
    
    SET v_days_in_period = 30;
    
    OPEN emp_cursor;
    
    read_loop: LOOP
        FETCH emp_cursor INTO v_emp_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Get active structure for employee
        SET v_struct_id = NULL;
        BEGIN
            DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
            SELECT structure_id, basic_pay, hra, educational_allowance, special_allowance, naac_allowance, gross_salary
            INTO v_struct_id, v_basic_pay, v_hra, v_edu_allowance, v_spec_allowance, v_naac_allowance, v_gross_salary
            FROM salary_structure
            WHERE employee_id = v_emp_id AND is_current = 1
            LIMIT 1;
        END;
        
        -- If no salary structure is defined, skip or create default empty
        IF v_struct_id IS NOT NULL THEN
            -- Initialize/reset calculation variables for each employee
            SET v_epf_base = 0;
            SET v_epf_rule_rate = 12.0;
            SET v_epf_rule_basis = 'basic_pay';
            SET v_esi_base = 0;
            SET v_esi_rule_rate = 0.75;
            SET v_esi_rule_basis = 'gross_salary';
            SET v_tds_amount = 0;
            SET v_pt_amount = 0;
            SET v_loan_deduction = 0;
            SET v_bus_fee = 0;

            -- Check if there are any attendance records for this period
            SET v_attendance_count = 0;
            SELECT COUNT(*) INTO v_attendance_count
            FROM attendance_daily
            WHERE employee_id = v_emp_id AND date BETWEEN v_start_date AND v_end_date;

            IF v_attendance_count = 0 THEN
                -- No records at all. Calculate all working days as LOP (excluding Sundays and holidays)
                SET v_weekend_holiday_count = 0;
                SET v_temp_date = v_start_date;
                WHILE v_temp_date <= v_end_date DO
                    IF DAYOFWEEK(v_temp_date) = 1 OR EXISTS (
                        SELECT 1 FROM holiday_master
                        WHERE is_active = 1
                          AND (employee_id = -1 OR employee_id = v_emp_id)
                          AND v_temp_date BETWEEN holiday_start_date AND holiday_end_date
                    ) THEN
                        SET v_weekend_holiday_count = v_weekend_holiday_count + 1;
                    END IF;
                    SET v_temp_date = DATE_ADD(v_temp_date, INTERVAL 1 DAY);
                END WHILE;
                SET v_lop_days = v_days_in_period - v_weekend_holiday_count;
            ELSE
                -- Calculate LOP days from attendance_daily
                SELECT COALESCE(SUM(deduction_days), 0)
                INTO v_lop_days
                FROM attendance_daily
                WHERE employee_id = v_emp_id AND date BETWEEN v_start_date AND v_end_date;
            END IF;
            
            -- LOP deduction amount
            SET v_lop_deduction = ROUND((v_gross_salary / v_days_in_period) * v_lop_days, 2);
            IF v_lop_deduction > v_gross_salary THEN
                SET v_lop_deduction = v_gross_salary;
            END IF;
            
            SET v_payable_amount = v_gross_salary - v_lop_deduction;
            
            -- EPF Calculation
            SET v_epf_amount = 0;
            -- Check if EPF is configured and applicable for employee (must exist and be active)
            IF EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'EPF' AND edc.is_applicable = 1) 
               AND EXISTS (SELECT 1 FROM deduction_rule_master WHERE deduction_code = 'EPF' AND is_active = 1) THEN
                
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT COALESCE(calc_basis, 'basic_pay'), COALESCE(rate, 12.0), applicable_months, COALESCE(projection_multiplier, 1)
                    INTO v_epf_rule_basis, v_epf_rule_rate, v_epf_rule_months, v_epf_rule_multiplier
                    FROM deduction_rule_master
                    WHERE deduction_code = 'EPF' AND is_active = 1;
                END;
               
                IF v_epf_rule_months IS NULL OR FIND_IN_SET(v_month, v_epf_rule_months) > 0 THEN
                    -- Base calculation based on dynamic calc_basis
                    IF v_epf_rule_basis = 'gross_salary' THEN
                        SET v_epf_base = ROUND(v_gross_salary * (1 - (v_lop_days / v_days_in_period)), 2);
                    ELSE
                        SET v_epf_base = ROUND(v_basic_pay * (1 - (v_lop_days / v_days_in_period)), 2);
                    END IF;
                    -- Apply wage ceiling
                    IF v_epf_base > 15000.00 THEN
                        SET v_epf_base = 15000.00;
                    END IF;
                    SET v_epf_amount = ROUND(v_epf_base * (v_epf_rule_rate / 100), 2);
                    
                    -- Apply custom overrides if set in employee_deduction_config
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT edc.override_amount
                        INTO v_epf_amount
                        FROM employee_deduction_config edc
                        JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                        WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'EPF' AND edc.is_applicable = 1 AND edc.override_amount IS NOT NULL
                        LIMIT 1;
                    END;
                END IF;
            END IF;
            
            -- ESI Calculation
            SET v_esi_amount = 0;
            IF EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'ESI' AND edc.is_applicable = 1)
               AND EXISTS (SELECT 1 FROM deduction_rule_master WHERE deduction_code = 'ESI' AND is_active = 1) THEN
                
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT COALESCE(calc_basis, 'gross_salary'), COALESCE(rate, 0.75), applicable_months, COALESCE(projection_multiplier, 1)
                    INTO v_esi_rule_basis, v_esi_rule_rate, v_esi_rule_months, v_esi_rule_multiplier
                    FROM deduction_rule_master
                    WHERE deduction_code = 'ESI' AND is_active = 1;
                END;

                IF v_esi_rule_months IS NULL OR FIND_IN_SET(v_month, v_esi_rule_months) > 0 THEN
                    -- Base calculation based on dynamic calc_basis
                    IF v_esi_rule_basis = 'basic_pay' THEN
                        SET v_esi_base = ROUND(v_basic_pay * (1 - (v_lop_days / v_days_in_period)), 2);
                    ELSE
                        SET v_esi_base = v_payable_amount;
                    END IF;
                    
                    -- Skip if base > 21000
                    IF v_esi_base <= 21000.00 THEN
                        SET v_esi_amount = ROUND(v_esi_base * (v_esi_rule_rate / 100), 2);
                    END IF;
                    
                    -- Apply custom overrides if set in employee_deduction_config
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT edc.override_amount
                        INTO v_esi_amount
                        FROM employee_deduction_config edc
                        JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                        WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'ESI' AND edc.is_applicable = 1 AND edc.override_amount IS NOT NULL
                        LIMIT 1;
                    END;
                END IF;
            END IF;
            
            -- TDS Calculation
            SET v_tds_amount = 0;
            IF EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'TDS' AND edc.is_applicable = 1) THEN
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT applicable_months, COALESCE(projection_multiplier, 1)
                    INTO v_tds_rule_months, v_tds_rule_multiplier
                    FROM deduction_rule_master
                    WHERE deduction_code = 'TDS' AND is_active = 1;
                END;

                IF v_tds_rule_months IS NULL OR FIND_IN_SET(v_month, v_tds_rule_months) > 0 THEN
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT COALESCE(tds_override_amount, 0)
                        INTO v_tds_amount
                        FROM employee_tds_config
                        WHERE employee_id = v_emp_id AND financial_year = CONCAT(v_year, '-', v_year+1)
                        LIMIT 1;
                    END;
                    
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT edc.override_amount
                        INTO v_tds_amount
                        FROM employee_deduction_config edc
                        JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                        WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'TDS' AND edc.is_applicable = 1 AND edc.override_amount IS NOT NULL
                        LIMIT 1;
                    END;
                END IF;
            END IF;
            
            -- Profession Tax (Slabs)
            SET v_pt_amount = 0;
            IF EXISTS (SELECT 1 FROM employee_deduction_config edc 
                           JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                           WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'PT' AND edc.is_applicable = 1) THEN
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT applicable_months, COALESCE(projection_multiplier, 1)
                    INTO v_pt_rule_months, v_pt_rule_multiplier
                    FROM deduction_rule_master
                    WHERE deduction_code = 'PT' AND is_active = 1;
                END;

                IF v_pt_rule_months IS NULL OR FIND_IN_SET(v_month, v_pt_rule_months) > 0 THEN
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT COALESCE(monthly_tax, 0)
                        INTO v_pt_amount
                        FROM profession_tax_slab
                        WHERE (v_payable_amount * v_pt_rule_multiplier) >= min_salary AND (max_salary IS NULL OR (v_payable_amount * v_pt_rule_multiplier) <= max_salary)
                          AND (effective_to IS NULL OR effective_to >= v_start_date)
                        ORDER BY min_salary DESC
                        LIMIT 1;
                    END;
                    
                    BEGIN
                        DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                        SELECT edc.override_amount
                        INTO v_pt_amount
                        FROM employee_deduction_config edc
                        JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                        WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'PT' AND edc.is_applicable = 1 AND edc.override_amount IS NOT NULL
                        LIMIT 1;
                    END;
                END IF;
            END IF;
            
            -- Loan / Salary Advance Deduction
            BEGIN
                DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                SELECT COALESCE(SUM(LEAST(monthly_deduction, balance_amount)), 0)
                INTO v_loan_deduction
                FROM employee_loan
                WHERE employee_id = v_emp_id AND status = 'active' AND balance_amount > 0
                  AND (deduction_start_year < v_year OR (deduction_start_year = v_year AND v_month >= deduction_start_month));
            END;
              
            -- Bus Fee or other custom deductions
            SET v_bus_fee = 0;
            BEGIN
                DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                SELECT applicable_months, COALESCE(projection_multiplier, 1)
                INTO v_bus_fee_rule_months, v_bus_fee_rule_multiplier
                FROM deduction_rule_master
                WHERE deduction_code = 'BUS_FEE' AND is_active = 1;
            END;

            IF v_bus_fee_rule_months IS NULL OR FIND_IN_SET(v_month, v_bus_fee_rule_months) > 0 THEN
                BEGIN
                    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;
                    SELECT COALESCE(edc.override_amount, drm.fixed_amount, 0)
                    INTO v_bus_fee
                    FROM employee_deduction_config edc
                    JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id
                    WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'BUS_FEE' AND edc.is_applicable = 1
                    LIMIT 1;
                END;
            END IF;
            
            -- Total Deductions
            SET v_total_deduction = v_epf_amount + v_esi_amount + v_tds_amount + v_pt_amount + v_loan_deduction + v_bus_fee;
            
            SET v_net_salary = v_payable_amount - v_total_deduction;
            IF v_net_salary < 0 THEN
                SET v_net_salary = 0;
            END IF;
            
            -- Construct JSON deductions (with all calculation bases and metadata)
            SET v_json_deductions = JSON_OBJECT(
                'EPF', v_epf_amount,
                'EPF_base', v_epf_base,
                'EPF_rate', v_epf_rule_rate,
                'ESI', v_esi_amount,
                'ESI_base', v_esi_base,
                'ESI_rate', v_esi_rule_rate,
                'TDS', v_tds_amount,
                'ProfessionTax', v_pt_amount,
                'LoanEMI', v_loan_deduction,
                'BusFee', v_bus_fee,
                'LOP_days', v_lop_days,
                'LOP_deduction', v_lop_deduction,
                'Gross_salary', v_gross_salary,
                'Basic_pay', v_basic_pay,
                'Payable_amount', v_payable_amount,
                'Days_in_period', v_days_in_period,
                'isEPFApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'EPF' AND edc.is_applicable = 1) AND (v_epf_rule_months IS NULL OR FIND_IN_SET(v_month, v_epf_rule_months) > 0) THEN 1 ELSE 0 END,
                'isESIApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'ESI' AND edc.is_applicable = 1) AND (v_esi_rule_months IS NULL OR FIND_IN_SET(v_month, v_esi_rule_months) > 0) THEN 1 ELSE 0 END,
                'isTDSApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'TDS' AND edc.is_applicable = 1) AND (v_tds_rule_months IS NULL OR FIND_IN_SET(v_month, v_tds_rule_months) > 0) THEN 1 ELSE 0 END,
                'isPTApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'PT' AND edc.is_applicable = 1) AND (v_pt_rule_months IS NULL OR FIND_IN_SET(v_month, v_pt_rule_months) > 0) THEN 1 ELSE 0 END,
                'isBusFeeApplicable', CASE WHEN EXISTS (SELECT 1 FROM employee_deduction_config edc JOIN deduction_rule_master drm ON edc.rule_id = drm.rule_id WHERE edc.employee_id = v_emp_id AND drm.deduction_code = 'BUS_FEE' AND edc.is_applicable = 1) AND (v_bus_fee_rule_months IS NULL OR FIND_IN_SET(v_month, v_bus_fee_rule_months) > 0) THEN 1 ELSE 0 END
            );
            
            -- Insert into salary_disbursement
            INSERT INTO salary_disbursement (
                employee_id, structure_id, period_id,
                basic_pay, hra, educational_allowance, special_allowance, naac_allowance, gross_salary,
                lop_days, payable_amount,
                deductions_json, total_deduction, net_salary,
                status, prepared_by, prepared_on
            ) VALUES (
                v_emp_id, v_struct_id, p_period_id,
                v_basic_pay, v_hra, v_edu_allowance, v_spec_allowance, v_naac_allowance, v_gross_salary,
                v_lop_days, v_payable_amount,
                v_json_deductions, v_total_deduction, v_net_salary,
                'draft', p_prepared_by, NOW()
            );
            
            -- Insert approval log
            INSERT INTO payroll_approval_log (
                disbursement_id, period_id, action, action_by, action_on, remarks, previous_status, new_status
            ) VALUES (
                LAST_INSERT_ID(), p_period_id, 'prepared', p_prepared_by, NOW(), 'Payroll run draft calculated', NULL, 'draft'
            );
            
        END IF;
    END LOOP;
    
    CLOSE emp_cursor;
    
    SELECT COUNT(*) AS processed_count FROM salary_disbursement WHERE period_id = p_period_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_save_approver_config` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin_test`@`localhost` PROCEDURE `sp_save_approver_config`(
    IN p_employee_id   INT,
    IN p_request_type  ENUM('LEAVE','REGULARISATION','ONDUTY'),
    IN p_approver_1_id INT,
    IN p_approver_2_id INT
)
BEGIN
    INSERT INTO employee_approver_configs (employee_id, request_type, approver_1_id, approver_2_id)
    VALUES (p_employee_id, p_request_type, p_approver_1_id, p_approver_2_id)
    ON DUPLICATE KEY UPDATE
        approver_1_id = p_approver_1_id,
        approver_2_id = p_approver_2_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_save_designation_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_save_designation_policy`(
    IN p_leave_policy_id INT,
    IN p_designation_id INT,
    IN p_policy_value LONGTEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    
    UPDATE leave_policy_designation SET active = 0 WHERE designation_id = p_designation_id;
    
    
    IF EXISTS (SELECT 1 FROM leave_policy_designation WHERE designation_id = p_designation_id AND leave_policy_id = p_leave_policy_id) THEN
        UPDATE leave_policy_designation 
        SET policy_value = p_policy_value, active = 1, created_by = p_created_by, created_on = NOW()
        WHERE designation_id = p_designation_id AND leave_policy_id = p_leave_policy_id;
    ELSE
        INSERT INTO leave_policy_designation (leave_policy_id, designation_id, policy_value, active, created_on, created_by)
        VALUES (p_leave_policy_id, p_designation_id, p_policy_value, 1, NOW(), p_created_by);
    END IF;
    
    SELECT 1 AS success;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_save_employee_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_save_employee_policy`(
    IN p_leave_policy_id INT,
    IN p_employee_id INT,
    IN p_policy_value LONGTEXT,
    IN p_created_by VARCHAR(45)
)
BEGIN
    
    UPDATE leave_policy_employee SET active = 0 WHERE employee_id = p_employee_id;
    
    
    IF EXISTS (SELECT 1 FROM leave_policy_employee WHERE employee_id = p_employee_id AND leave_policy_id = p_leave_policy_id) THEN
        UPDATE leave_policy_employee 
        SET policy_value = p_policy_value, active = 1, created_by = p_created_by, created_on = NOW()
        WHERE employee_id = p_employee_id AND leave_policy_id = p_leave_policy_id;
    ELSE
        INSERT INTO leave_policy_employee (leave_policy_id, employee_id, policy_value, active, created_on, created_by)
        VALUES (p_leave_policy_id, p_employee_id, p_policy_value, 1, NOW(), p_created_by);
    END IF;
    
    SELECT 1 AS success;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_save_exceptional_day` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_save_exceptional_day`(
    IN p_exceptional_id INT,
    IN p_holiday_date DATE,
    IN p_description VARCHAR(255),
    IN p_is_active TINYINT
)
BEGIN
    IF p_exceptional_id IS NULL OR p_exceptional_id = 0 THEN
        INSERT INTO exceptional_days (holiday_date, description, is_active)
        VALUES (p_holiday_date, p_description, p_is_active)
        ON DUPLICATE KEY UPDATE 
            description = VALUES(description),
            is_active = VALUES(is_active);
        SELECT LAST_INSERT_ID() AS exceptional_id;
    ELSE
        UPDATE exceptional_days SET
            holiday_date = p_holiday_date,
            description = p_description,
            is_active = p_is_active
        WHERE exceptional_id = p_exceptional_id;
        SELECT p_exceptional_id AS exceptional_id;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_save_holiday` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_save_holiday`(
    IN p_holiday_id INT,
    IN p_holiday_date DATE,
    IN p_description VARCHAR(255),
    IN p_is_active TINYINT
)
BEGIN
    IF p_holiday_id IS NULL OR p_holiday_id = 0 THEN
        INSERT INTO holidays (holiday_date, description, is_active)
        VALUES (p_holiday_date, p_description, p_is_active)
        ON DUPLICATE KEY UPDATE description = p_description, is_active = p_is_active;
        SELECT LAST_INSERT_ID() AS holiday_id;
    ELSE
        UPDATE holidays SET
            holiday_date = p_holiday_date,
            description = p_description,
            is_active = p_is_active
        WHERE holiday_id = p_holiday_id;
        SELECT p_holiday_id AS holiday_id;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_save_role_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_save_role_policy`(
    IN p_leave_policy_id INT,
    IN p_role_id INT,
    IN p_policy_value LONGTEXT,
    IN p_weekly_off TEXT,
    IN p_created_by VARCHAR(100)
)
BEGIN
    INSERT INTO leave_policy_role (
        leave_policy_id, role_id, policy_value, weekly_off, created_by
    ) VALUES (
        p_leave_policy_id, p_role_id, p_policy_value, p_weekly_off, p_created_by
    )
    ON DUPLICATE KEY UPDATE 
        policy_value = VALUES(policy_value),
        weekly_off = VALUES(weekly_off),
        active = 1;
        
    SELECT LAST_INSERT_ID() AS leave_policy_role_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_save_role_privilage` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_save_role_privilage`(
    IN p_role_id INT,
    IN p_settings_id INT,
    IN p_privilage_value JSON
)
BEGIN
    DECLARE v_id INT;
    
    SELECT role_privilage_id INTO v_id 
    FROM app_role_privilage 
    WHERE role_id = p_role_id AND settings_id = p_settings_id;
    
    IF v_id IS NOT NULL THEN
        UPDATE app_role_privilage 
        SET privilage_value = p_privilage_value
        WHERE role_privilage_id = v_id;
    ELSE
        INSERT INTO app_role_privilage(role_id, settings_id, privilage_value)
        VALUES(p_role_id, p_settings_id, p_privilage_value);
    END IF;
    
    SELECT v_id AS role_privilage_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_save_role_privilege` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_save_role_privilege`(
    IN p_role_id INT,
    IN p_settings_id INT,
    IN p_privilege_value JSON
)
BEGIN
    DECLARE v_id INT;
    
    SELECT app_role_privilege_id INTO v_id 
    FROM app_role_privilege 
    WHERE role_id = p_role_id AND settings_id = p_settings_id;
    
    IF v_id IS NOT NULL THEN
        UPDATE app_role_privilege 
        SET app_privilege_value = p_privilege_value
        WHERE app_role_privilege_id = v_id;
    ELSE
        INSERT INTO app_role_privilege(role_id, settings_id, app_privilege_value, created_on)
        VALUES(p_role_id, p_settings_id, p_privilege_value, NOW());
    END IF;
    
    SELECT v_id AS app_role_privilege_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_set_active_leave_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_set_active_leave_policy`(
    IN p_leave_policy_id INT
)
BEGIN
    DECLARE v_policy_year INT;
    DECLARE v_policy_value LONGTEXT;
    DECLARE v_weekly_off TEXT;
    DECLARE v_created_by VARCHAR(45);

    
    SELECT policy_year, policy_value, weekly_off, created_by
    INTO v_policy_year, v_policy_value, v_weekly_off, v_created_by
    FROM leave_policy 
    WHERE leave_policy_id = p_leave_policy_id
    LIMIT 1;

    
    UPDATE leave_policy 
    SET active = 0 
    WHERE policy_year = v_policy_year;

    
    UPDATE leave_policy 
    SET active = 1 
    WHERE leave_policy_id = p_leave_policy_id;
    
    
    UPDATE leave_policy_system 
    SET active = 0 
    WHERE policy_year = v_policy_year;

    INSERT INTO leave_policy_system (
        leave_policy_id, policy_value, weekly_off, policy_year, active, created_by
    )
    VALUES (
        p_leave_policy_id, v_policy_value, v_weekly_off, v_policy_year, 1, v_created_by
    )
    ON DUPLICATE KEY UPDATE 
        leave_policy_id = VALUES(leave_policy_id),
        policy_value = VALUES(policy_value),
        weekly_off = VALUES(weekly_off),
        active = 1;
    
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_sync_leave_accrual` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_sync_leave_accrual`(
    IN p_emp_id INT,
    IN p_leave_type VARCHAR(50),
    IN p_month_year VARCHAR(7),
    IN p_target_year INT,
    IN p_target_month INT,
    IN p_credit_amount DECIMAL(10,2),
    IN p_is_dry_run BOOLEAN,
    IN p_start_month INT
)
BEGIN
    DECLARE v_opening_leave DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_leaves_taken DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_last_balance DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_found_last BOOLEAN DEFAULT FALSE;

    -- 1. Find the LATEST available balance BEFORE the target month
    SELECT balance_leave INTO v_last_balance
    FROM employee_leaves
    WHERE emp_id = p_emp_id AND leave_type = p_leave_type
    AND (
        CAST(SUBSTRING_INDEX(month_year, '-', -1) AS UNSIGNED) < p_target_year
        OR (
            CAST(SUBSTRING_INDEX(month_year, '-', -1) AS UNSIGNED) = p_target_year
            AND CAST(SUBSTRING_INDEX(month_year, '-', 1) AS UNSIGNED) < p_target_month
        )
    )
    ORDER BY CAST(SUBSTRING_INDEX(month_year, '-', -1) AS UNSIGNED) DESC, 
             CAST(SUBSTRING_INDEX(month_year, '-', 1) AS UNSIGNED) DESC 
    LIMIT 1;

    IF v_last_balance IS NOT NULL THEN
        SET v_found_last = TRUE;
    ELSE
        SET v_last_balance = 0.00;
    END IF;

    -- 2. Handle Year-End Reset Logic (Month-to-Month is always carried forward)
    IF p_target_month = p_start_month THEN
        -- At the start of the year, we normally reset (based on policy)
        -- But for this sync, we'll let the JS handle the 'Carry Forward' boolean
        -- For now, we assume the opening is what we passed or found
        SET v_opening_leave = v_last_balance;
    ELSE
        -- Within the year, we ALWAYS carry forward
        SET v_opening_leave = v_last_balance;
    END IF;

    -- 3. Calculate Leaves Actually Taken in this month
    SELECT COALESCE(SUM(total_days), 0.00) INTO v_leaves_taken
    FROM leave_requests
    WHERE employee_id = p_emp_id 
    AND leave_type = p_leave_type
    AND status = 'Approved'
    AND DATE_FORMAT(start_date, '%m-%Y') = p_month_year;

    -- 4. Final results
    IF p_is_dry_run = FALSE THEN
        INSERT INTO employee_leaves (emp_id, leave_type, month_year, opening_leave, credited_count, leaves_taken)
        VALUES (p_emp_id, p_leave_type, p_month_year, v_opening_leave, p_credit_amount, v_leaves_taken)
        ON DUPLICATE KEY UPDATE
            opening_leave = VALUES(opening_leave),
            credited_count = VALUES(credited_count),
            leaves_taken = VALUES(leaves_taken);
    END IF;

    -- Return the values for the report
    SELECT 
        v_opening_leave as openingLeave, 
        p_credit_amount as creditAmount, 
        v_leaves_taken as leavesTaken,
        (v_opening_leave + p_credit_amount) as total,
        (v_opening_leave + p_credit_amount - v_leaves_taken) as balance;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_attendance_setting` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_update_attendance_setting`(
    IN p_key VARCHAR(100),
    IN p_value VARCHAR(255)
)
BEGIN
    UPDATE attendance_settings SET setting_value = p_value WHERE setting_key = p_key;
    SELECT ROW_COUNT() AS updated;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_department` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_update_department`(
    IN p_department_id INT,
    IN p_departmentname VARCHAR(45)
)
BEGIN
    UPDATE department
    SET departmentname = p_departmentname
    WHERE department_id = p_department_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_designation` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_update_designation`(
    IN p_designation_id INT,
    IN p_designation VARCHAR(45)
)
BEGIN
    UPDATE designation
    SET designation = p_designation
    WHERE designation_id = p_designation_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_employee` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_update_employee`(
    IN p_employee_id INT,
    IN p_organization_id INT,
    IN p_employee_code VARCHAR(45),
    IN p_employee_name VARCHAR(200),
    IN p_email VARCHAR(200),
    IN p_role_id INT,
    IN p_designation_id INT,
    IN p_reporting_manager_id INT,
    IN p_joining_date DATE,
    IN p_active TINYINT,
    IN p_modified_by VARCHAR(45),
    IN p_department_id INT,
    IN p_basic_pay DECIMAL(15,2)
)
BEGIN
    UPDATE employee SET
        organization_id = p_organization_id,
        employee_code = p_employee_code,
        employee_name = p_employee_name,
        email = p_email,
        role_id = p_role_id,
        designation_id = p_designation_id,
        reporting_manager_id = p_reporting_manager_id,
        joining_date = p_joining_date,
        active = p_active,
        modified_by = p_modified_by,
        modified_on = NOW(),
        department_id = p_department_id,
        basic_pay = p_basic_pay
    WHERE employee_id = p_employee_id;

    -- Sync active status to user accounts
    UPDATE user_accounts SET active = p_active WHERE employee_id = p_employee_id;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_leave_policy` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_update_leave_policy`(
    IN p_leave_policy_id INT,
    IN p_policy_name VARCHAR(245),
    IN p_policy_year INT,
    IN p_policy_value LONGTEXT,
    IN p_weekly_off TEXT
)
BEGIN
    DECLARE v_active INT;

    UPDATE leave_policy 
    SET policy_name = p_policy_name, 
        policy_year = p_policy_year, 
        policy_value = p_policy_value,
        weekly_off = p_weekly_off
    WHERE leave_policy_id = p_leave_policy_id;

    
    SELECT active INTO v_active 
    FROM leave_policy 
    WHERE leave_policy_id = p_leave_policy_id
    LIMIT 1;

    
    IF v_active = 1 THEN
        INSERT INTO leave_policy_system (
            leave_policy_id, policy_value, weekly_off, policy_year, active, created_by
        )
        VALUES (
            p_leave_policy_id, p_policy_value, p_weekly_off, p_policy_year, 1, 'System Sync'
        )
        ON DUPLICATE KEY UPDATE 
            policy_value = VALUES(policy_value),
            weekly_off = VALUES(weekly_off),
            policy_year = VALUES(policy_year),
            active = 1;
    END IF;

    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_user_otp` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`localhost` PROCEDURE `sp_update_user_otp`(
    IN p_email VARCHAR(255),
    IN p_otp INT
)
BEGIN
    UPDATE user_accounts 
    SET otp = p_otp, 
        otp_generated_on = NOW()
    WHERE email = p_email;
    
    SELECT ROW_COUNT() AS affected_rows;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-14 13:49:05
