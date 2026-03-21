const SettingsModel = require('../models/settingsModel');
const { sendResponse } = require('../utils/responseHelper');

const getSetting = async (req, res, next) => {
    try {
        const { key } = req.params;
        const setting = await SettingsModel.getSettingByKey(key);
        if (!setting) {
            return res.status(404).json({ success: false, message: 'Setting not found' });
        }
        sendResponse(res, 200, 'Setting fetched successfully', setting);
    } catch (error) {
        next(error);
    }
};

module.exports = { getSetting };
