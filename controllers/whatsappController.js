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

const testPdf = async (req, res, next) => {
    try {
        const url = 'https://automate.bizylead.com/api/v2/whatsapp-business/messages';
        const token = '66f8d777106c6c0b60749ee3859b6c8a601b415b6f411eb63cb0cb0279831aee';
        
        const payload = {
            "to": "917558978583",
            "phoneNoId": "1222720630928340",
            "type": "document",
            "url": "https://pdfobject.com/pdf/sample.pdf",
            "caption": "Important document",
            "filename": "invoice.pdf"
        };

        console.log('[WhatsApp API Debug] Triggering Bizylead PDF Send to:', payload.to);

        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify(payload)
        });

        const data = await response.json();
        console.log('[WhatsApp API Debug] Bizylead API response code:', response.status, data);
        
        return res.status(response.status).json({
            success: response.ok,
            apiResponse: data
        });
    } catch (error) {
        console.error('[WhatsApp API Debug] Bizylead API error:', error);
        next(error);
    }
};

module.exports = {
    handleMessage,
    testPdf
};
