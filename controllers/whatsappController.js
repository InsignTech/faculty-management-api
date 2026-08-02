const { sendResponse } = require('../utils/responseHelper');

const handleMessage = async (req, res, next) => {
    try {
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
