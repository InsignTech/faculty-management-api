const { sendResponse } = require('../utils/responseHelper');

const handleMessage = async (req, res, next) => {
    try {
        const endTime = Date.now();
        const duration = endTime - (req.startTime || endTime);
        console.log(`[WhatsApp API] Response sent at: ${new Date(endTime).toISOString()} | Duration: ${duration}ms`);

        if (!req.userExist) {
            return res.status(200).json({
                success: true,
                userExist: false,
                emp_name: ""
            });
        }

        const employee = req.employee;

        return res.status(200).json({
            success: true,
            userExist: true,
            emp_name: employee.employee_name
        });
    } catch (error) {
        next(error);
    }
};

module.exports = {
    handleMessage
};
