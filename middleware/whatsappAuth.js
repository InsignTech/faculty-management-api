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

    const startTime = Date.now();
    req.startTime = startTime;
    console.log(`[WhatsApp API] Request received at: ${new Date(startTime).toISOString()} for Phone: ${req.body.Phone || 'unknown'}`);

    try {
        const employee = await EmployeeModel.findByPhone(Phone);
        if (!employee) {
            req.userExist = false;
            req.employee = null;
        } else {
            req.userExist = true;
            req.employee = employee;
        }
        next();
    } catch (error) {
        next(error);
    }
};

module.exports = whatsappAuth;
