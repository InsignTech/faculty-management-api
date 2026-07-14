DROP PROCEDURE IF EXISTS `sp_request_leave_encashment`;

DELIMITER ;;
CREATE PROCEDURE `sp_request_leave_encashment`(
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
