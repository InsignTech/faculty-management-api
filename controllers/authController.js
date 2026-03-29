const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const UserModel = require('../models/userModel');
const { sendResponse } = require('../utils/responseHelper');
const ErrorResponse = require('../utils/errorResponse');
const { sendOTPEmail } = require('../utils/emailService');

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

        const isMatch = await bcrypt.compare(password, user.user_password);

        if (!isMatch) {
            return next(new ErrorResponse('Invalid credentials', 401, 'UNAUTHORIZED'));
        }

        const token = jwt.sign(
            { id: user.user_accounts_id, role: user.role_name, roleId: user.role_id, employeeId: user.employee_id },
            process.env.JWT_SECRET || 'fallback_secret',
            { expiresIn: process.env.JWT_EXPIRES_IN || '1d' }
        );

        sendResponse(res, 200, 'Login successful', {
            token,
            user: {
                id: user.user_accounts_id,
                user_display_name: user.user_display_name,
                email: user.email,
                role: user.role_name,
                roleId: user.role_id,
                employeeId: user.employee_id
            },
        });
    } catch (error) {
        next(error);
    }
};

const requestOTP = async (req, res, next) => {
    try {
        const { email } = req.body;
        if (!email) {
            return next(new ErrorResponse('Please provide an email', 400, 'VALIDATION_ERROR'));
        }

        const user = await UserModel.findByEmail(email);
        if (!user) {
            // Return success even if not found to prevent email enumeration
            return sendResponse(res, 200, 'If an account exists, an OTP will be sent to the email address.');
        }

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000);
        
        await UserModel.updateOTP(email, otp);

        // Send OTP via email
        try {
            await sendOTPEmail({ toEmail: email, otp });
        } catch (emailErr) {
            console.error(`Failed to send OTP email to ${email}:`, emailErr.message);
        }

        sendResponse(res, 200, 'If an account exists, an OTP will be sent to the email address.');
    } catch (error) {
        next(error);
    }
};

const resetWithOTP = async (req, res, next) => {
    try {
        const { email, otp, newPassword } = req.body;
        if (!email || !otp || !newPassword) {
            return next(new ErrorResponse('Please provide email, otp, and new password', 400, 'VALIDATION_ERROR'));
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(newPassword, salt);

        const result = await UserModel.resetPasswordWithOTP(email, otp, hashedPassword);
        
        if (result.affected_rows === 0) {
            return next(new ErrorResponse('Invalid or expired OTP', 400, 'INVALID_OTP'));
        }

        sendResponse(res, 200, 'Password reset successful. You can now login.');
    } catch (error) {
        next(error);
    }
};

const resetWithOldPassword = async (req, res, next) => {
    try {
        const { oldPassword, newPassword } = req.body;
        
        if (!oldPassword || !newPassword) {
            return next(new ErrorResponse('Please provide old and new passwords', 400, 'VALIDATION_ERROR'));
        }

        // We assume req.user is set by auth middleware
        if (!req.user || !req.user.id) {
            return next(new ErrorResponse('Unauthorized', 401, 'UNAUTHORIZED'));
        }

        // Use findByEmail workaround if findById is absent, or assume it's there
        // Actually findById is removed, let's use the email from token if available, or we might need findById.
        // Let's add findById back in the model in the next step, or just use it assuming it'll be there.
        // Let's assume we have req.user.email from token, or we can add it to the token.
        // For simplicity, let's use a standard pool query here if we don't want to re-modify the model immediately, 
        // or better, I will update userModel via another call. I'll just rely on a new userModel method `findById` which I'll add.
        const user = await UserModel.findById(req.user.id);

        if (!user) {
            return next(new ErrorResponse('User not found', 404, 'NOT_FOUND'));
        }

        const isMatch = await bcrypt.compare(oldPassword, user.user_password);
        
        if (!isMatch) {
            return next(new ErrorResponse('Invalid old password', 400, 'INVALID_CREDENTIALS'));
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(newPassword, salt);

        await UserModel.resetPasswordWithOld(user.user_accounts_id, hashedPassword);

        sendResponse(res, 200, 'Password updated successfully');
    } catch (error) {
        next(error);
    }
};

module.exports = { signup, login, requestOTP, resetWithOTP, resetWithOldPassword };
