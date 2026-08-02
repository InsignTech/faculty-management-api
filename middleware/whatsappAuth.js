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

    console.log('[WhatsApp API Debug] Incoming Request Body:', JSON.stringify(req.body, null, 2));

    // Support both nested webhook format and direct flat format
    const Phone = req.body.Phone || (req.body.data && req.body.data.senderPhoneNumber);
    const message = req.body.message || (req.body.data && req.body.data.content && req.body.data.content.text);

    console.log(`[WhatsApp API Debug] Parsed values - Phone: "${Phone}", Message: "${message}"`);

    if (!Phone) {
        console.log('[WhatsApp API Debug] Validation failed: Phone is missing');
        return res.status(400).json({
            success: false,
            message: 'Phone number is required in request body (e.g. Phone or data.senderPhoneNumber).',
            errorCode: 'PHONE_REQUIRED'
        });
    }

    // Validate that the message is a greeting
    const greetings = ['hi', 'hello', 'hlo', 'hey', 'start'];
    const cleanMessage = (message || '').trim().toLowerCase();
    if (!greetings.includes(cleanMessage)) {
        console.log(`[WhatsApp API Debug] Message is not an allowed greeting. Allowed: ${greetings.join(', ')}. Received: "${cleanMessage}"`);
        return res.status(200).json({
            success: true,
            userExist: false,
            emp_name: ""
        });
    }

    const startTime = Date.now();
    req.startTime = startTime;
    console.log(`[WhatsApp API] Request received at: ${new Date(startTime).toISOString()} for Phone: ${Phone}`);

    try {
        console.log(`[WhatsApp API Debug] Querying database for phone: ${Phone}`);
        const employee = await EmployeeModel.findByPhone(Phone);
        if (!employee) {
            console.log(`[WhatsApp API Debug] Lookup failed: No active employee found for phone: ${Phone}`);
            req.userExist = false;
            req.employee = null;
        } else {
            console.log(`[WhatsApp API Debug] Lookup success: Employee found is "${employee.employee_name}" (ID: ${employee.employee_id})`);
            req.userExist = true;
            req.employee = employee;
        }
        next();
    } catch (error) {
        console.error('[WhatsApp API Debug] Database query error:', error);
        next(error);
    }
};

module.exports = whatsappAuth;
