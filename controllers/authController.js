const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const UserModel = require('../models/userModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');

const signup = async (req, res, next) => {
    try {
        const { username, email, password, role } = req.body;

        if (!username || !email || !password || !role) {
            return next(new ErrorResponse('Please provide all required fields', 400, 'VALIDATION_ERROR'));
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        const user = await UserModel.signup(username, email, hashedPassword, role);

        sendResponse(res, 201, 'User registered successfully', user);
    } catch (error) {
        next(error);
    }
};

const login = async (req, res, next) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return next(new ErrorResponse('Please provide email and password', 400, 'VALIDATION_ERROR'));
        }

        const user = await UserModel.findByEmail(email);

        if (!user) {
            return next(new ErrorResponse('Invalid credentials', 401, 'UNAUTHORIZED'));
        }

        const isMatch = await bcrypt.compare(password, user.password);

        if (!isMatch) {
            return next(new ErrorResponse('Invalid credentials', 401, 'UNAUTHORIZED'));
        }

        const token = jwt.sign(
            { id: user.id, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN }
        );

        sendResponse(res, 200, 'Login successful', {
            token,
            user: {
                id: user.id,
                username: user.username,
                email: user.email,
                role: user.role,
            },
        });
    } catch (error) {
        next(error);
    }
};

module.exports = { signup, login };
