const express = require('express');
const morgan = require('morgan');
const setupSecurity = require('./middleware/security');
const errorHandler = require('./middleware/errorHandler');
const healthRoutes = require('./routes/healthRoutes');
const authRoutes = require('./routes/authRoutes');
const departmentRoutes = require('./routes/departmentRoutes');
const employeeRoutes = require('./routes/employeeRoutes');
const roleRoutes = require('./routes/roleRoutes');
const settingsRoutes = require('./routes/settingsRoutes');
const privilageRoutes = require('./routes/privilageRoutes');
const designationRoutes = require('./routes/designationRoutes');
const leavePolicyRoutes = require('./routes/leavePolicyRoutes');
const leaveRequestRoutes = require('./routes/leaveRequestRoutes');
const setupSwagger = require('./utils/swagger');

const app = express();

// Body parser
app.use(express.json());

// Dev logging middleware
if (process.env.NODE_ENV === 'development') {
    app.use(morgan('dev'));
}

// Setup Security Middlewares
setupSecurity(app);

// Setup Swagger
setupSwagger(app);

// Mount routers
app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/departments', departmentRoutes);
app.use('/api/employees', employeeRoutes);
app.use('/api/roles', roleRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/privileges', privilageRoutes);
app.use('/api/designations', designationRoutes);
app.use('/api/leave-policies', leavePolicyRoutes);
app.use('/api/leave-requests', leaveRequestRoutes);

// 404 handler for undefined routes
app.use((req, res, next) => {
    res.status(404).json({
        success: false,
        message: `Route ${req.originalUrl} not found`,
        errorCode: 'NOT_FOUND'
    });
});

// Error handler (must be last)
app.use(errorHandler);

module.exports = app;
