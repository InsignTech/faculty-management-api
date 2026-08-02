const EmployeeModel = require('../models/employeeModel');

const whatsappAuth = async (req, res, next) => {
    // Check if whatsapp bot is enabled in configuration
    const isBotEnabled = (process.env.is_whatsapp_bot_enabled || process.env.IS_WHATSAPP_BOT_ENABLED || 'true').trim().toLowerCase() === 'true';
    if (!isBotEnabled) {
        return res.status(403).json({
            success: false,
            message: 'WhatsApp Bot is disabled.',
            errorCode: 'BOT_DISABLED'
        });
    }

    const { Phone } = req.body;
    if (!Phone) {
        return res.status(400).json({
            success: false,
            message: 'Phone number is required in request body.',
            errorCode: 'PHONE_REQUIRED'
        });
    }

    try {
        const employee = await EmployeeModel.findByPhone(Phone);
        if (!employee) {
            return res.status(404).json({
                success: false,
                message: 'Employee not found with the provided phone number.',
                errorCode: 'EMPLOYEE_NOT_FOUND'
            });
        }

        // Attach employee to request object for downstream usage
        req.employee = employee;
        next();
    } catch (error) {
        next(error);
    }
};

module.exports = whatsappAuth;
