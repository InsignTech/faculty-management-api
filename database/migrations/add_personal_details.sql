ALTER TABLE `employee`
ADD COLUMN `title` VARCHAR(10) NULL,
ADD COLUMN `gender` VARCHAR(15) NULL,
ADD COLUMN `dob` DATE NULL,
ADD COLUMN `marital_status` VARCHAR(20) NULL,
ADD COLUMN `nationality` VARCHAR(45) NULL,
ADD COLUMN `blood_group` VARCHAR(5) NULL,
ADD COLUMN `place_of_birth` VARCHAR(100) NULL,
ADD COLUMN `state_of_birth` VARCHAR(100) NULL,
ADD COLUMN `religion` VARCHAR(45) NULL,
ADD COLUMN `identification_mark` VARCHAR(255) NULL,
ADD COLUMN `mother_tongue` VARCHAR(45) NULL;

CREATE TABLE `employee_personal_ids` (
  `employee_id` INT NOT NULL,
  `aadhar_number` VARCHAR(50) NULL,
  `aadhar_file` VARCHAR(255) NULL,
  `pan_number` VARCHAR(50) NULL,
  `pan_file` VARCHAR(255) NULL,
  `passport_number` VARCHAR(50) NULL,
  `passport_file` VARCHAR(255) NULL,
  `voter_id_number` VARCHAR(50) NULL,
  `voter_id_file` VARCHAR(255) NULL,
  `driving_licence_number` VARCHAR(50) NULL,
  `driving_licence_file` VARCHAR(255) NULL,
  `uan_number` VARCHAR(50) NULL,
  `uan_file` VARCHAR(255) NULL,
  PRIMARY KEY (`employee_id`),
  FOREIGN KEY (`employee_id`) REFERENCES `employee` (`employee_id`) ON DELETE CASCADE
);
