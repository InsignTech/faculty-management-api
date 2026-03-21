const errorHandler = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;

  // Log to console for dev
  if (process.env.NODE_ENV === 'development') {
    console.error(err);
  }

  // MySQL Duplicate Entry
  if (err.code === 'ER_DUP_ENTRY') {
    error.message = 'Duplicate entry found';
    error.statusCode = 400;
    error.errorCode = 'DUPLICATE_ENTRY';
  }

  // Joi validation error
  if (err.isJoi) {
    error.statusCode = 400;
    error.message = err.details.map((d) => d.message).join(', ');
    error.errorCode = 'VALIDATION_ERROR';
  }

  const statusCode = error.statusCode || 500;
  const message = error.message || 'Internal Server Error';
  const errorCode = error.errorCode || 'INTERNAL_SERVER_ERROR';

  res.status(statusCode).json({
    success: false,
    message,
    errorCode,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  });
};

module.exports = errorHandler;
