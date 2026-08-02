const { sendResponse } = require('../utils/responseHelper');

const handleMessage = async (req, res, next) => {
    try {
        if (!req.userExist) {
            return res.status(200).json({
                success: true,
                userExist: false,
                message: 'Employee not found with the provided phone number.'
            });
        }

        const employee = req.employee;
        const employeeName = employee.employee_name;

        // Custom greeting message based on the requirement
        const welcomeMessage = `Welcome ${employeeName},

Please select:
1. View Attendance
2. View Leave`;

        return res.status(200).json({
            success: true,
            userExist: true,
            message: welcomeMessage,
            data: {
                employee_id: employee.employee_id,
                employee_code: employee.employee_code,
                employee_name: employee.employee_name
            }
        });
    } catch (error) {
        next(error);
    }
};

module.exports = {
    handleMessage
};
