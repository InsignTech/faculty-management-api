const RoleModel = require('../models/roleModel');
const { sendResponse } = require('../utils/responseHelper');

const getRoles = async (req, res, next) => {
    try {
        const roles = await RoleModel.getAll();
        sendResponse(res, 200, 'Roles fetched successfully', roles);
    } catch (error) {
        next(error);
    }
};

const createRole = async (req, res, next) => {
    try {
        const { role } = req.body;
        if (!role) {
            return res.status(400).json({ success: false, message: 'Role name is required' });
        }
        const newRole = await RoleModel.create(role);
        sendResponse(res, 201, 'Role created successfully', newRole);
    } catch (error) {
        next(error);
    }
};

module.exports = { getRoles, createRole };
