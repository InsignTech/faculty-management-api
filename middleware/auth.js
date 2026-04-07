const jwt = require('jsonwebtoken');

const protect = (req, res, next) => {
    let token;
    if (
        req.headers.authorization &&
        req.headers.authorization.startsWith('Bearer')
    ) {
        token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
        return res.status(401).json({
            success: false,
            message: 'Not authorized to access this route',
            errorCode: 'UNAUTHORIZED',
        });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        return res.status(401).json({
            success: false,
            message: 'Token is invalid or expired',
            errorCode: 'INVALID_TOKEN',
        });
    }
};
const authorize = (...roles) => {
    return (req, res, next) => {
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({
                success: false,
                message: `User role ${req.user.role} is not authorized to access this route`,
                errorCode: 'FORBIDDEN',
            });
        }
        next();
    };
};

const protectMachine = (req, res, next) => {
    const machineKey = req.headers['x-api-key'];
    const VALID_KEY = process.env.MACHINE_API_KEY || 'SD-MACHINE-SECURE-KEY-2024';

    if (!machineKey || machineKey !== VALID_KEY) {
        return res.status(401).json({
            success: false,
            message: 'Invalid or missing Machine API Key',
            errorCode: 'UNAUTHORIZED_MACHINE',
        });
    }

    req.user = { role: 'Admin', employeeId: 0, name: 'Machine_Link' };
    next();
};

module.exports = { protect, authorize, protectMachine };
