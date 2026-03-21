const PrivilageModel = require('../models/privilageModel');
const { sendResponse } = require('../utils/responseHelper');

const getRolePrivileges = async (req, res, next) => {
    try {
        const { roleId } = req.params;
        const privileges = await PrivilageModel.getByRoleId(roleId);
        sendResponse(res, 200, 'Privileges fetched successfully', privileges);
    } catch (error) {
        next(error);
    }
};

const saveRolePrivileges = async (req, res, next) => {
    try {
        const { roleId, settingsId, privileges } = req.body;
        if (!roleId || !settingsId || !privileges) {
            return res.status(400).json({ success: false, message: 'roleId, settingsId, and privileges are required' });
        }
        await PrivilageModel.save(roleId, settingsId, privileges);
        sendResponse(res, 200, 'Privileges saved successfully');
    } catch (error) {
        next(error);
    }
};

module.exports = { getRolePrivileges, saveRolePrivileges };
