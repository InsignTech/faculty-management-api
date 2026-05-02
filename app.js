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
const attendanceRoutes = require('./routes/attendanceRoutes');
const holidayRoutes = require('./routes/holidayRoutes');
const reportRoutes = require('./routes/reportRoutes');
const exceptionalRoutes = require('./routes/exceptionalRoutes');
const leaveRoutes = require('./routes/leaveRoutes');
const leaveEncashmentRoutes = require('./routes/leaveEncashmentRoutes');
const shiftRoutes = require('./routes/shiftRoutes');
const setupSwagger = require('./utils/swagger');
const debugLog = require('./utils/debugLogger');

debugLog("Step 4: Creating Express app...");
const app = express();

// Trust proxy - needed for express-rate-limit on hosted environments
app.set('trust proxy', 1);

debugLog("Step 5: Setting up middleware...");
// Body parser
app.use(express.json());


// Dev logging middleware
if (process.env.NODE_ENV === 'development') {
    app.use(morgan('dev'));
}

debugLog("Step 6: Setting up security...");
// Setup Security Middlewares
setupSecurity(app);

debugLog("Step 7: Setting up Swagger...");
// Setup Swagger
setupSwagger(app);

debugLog("Step 8: Mounting routes...");
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
app.use('/api/attendance', attendanceRoutes);
app.use('/api/holidays', holidayRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/exceptional', exceptionalRoutes);
app.use('/api/leaves', leaveRoutes);
app.use('/api/leave-encashments', leaveEncashmentRoutes);
app.use('/api/shifts', shiftRoutes);

// 404 handler for undefined routes
app.use((req, res, next) => {
    res.status(404).json({
        success: false,
        message: `Route ${req.originalUrl} not found`,
        errorCode: 'NOT_FOUND'
    });
});

debugLog("Step 9: Setting up global error handler...");
// Error handler (must be last)
app.use(errorHandler);

debugLog("Step 10: App ready to export.");
module.exports = app;
