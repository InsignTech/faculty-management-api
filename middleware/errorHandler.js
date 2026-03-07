const errorHandler = (err, req, res, next) => {
    let error = { ...err };
    error.message = err.message;

    // Log to console for dev
    console.error(err);

    // Default error
    let statusCode = error.statusCode || 500;
    let message = error.message || 'Internal Server Error';
    let errorCode = error.errorCode || 'INTERNAL_SERVER_ERROR';

    // Joi validation error
    if (err.isJoi) {
        statusCode = 400;
        message = err.details.map((d) => d.message).join(', ');
        errorCode = 'VALIDATION_ERROR';
    }

    res.status(statusCode).json({
        success: false,
        message,
        errorCode,
        stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
    });
};

module.exports = errorHandler;
