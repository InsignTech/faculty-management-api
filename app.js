const express = require('express');
const morgan = require('morgan');
const setupSecurity = require('./middleware/security');
const errorHandler = require('./middleware/errorHandler');
const healthRoutes = require('./routes/healthRoutes');
const authRoutes = require('./routes/authRoutes');
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

// Error handler (must be last)
app.use(errorHandler);

module.exports = app;
