const nodemailer = require('nodemailer');

/**
 * Creates a nodemailer transporter using environment variables.
 * Configure these in your .env file:
 *
 * EMAIL_HOST=smtp.gmail.com
 * EMAIL_PORT=587
 * EMAIL_SECURE=false
 * EMAIL_USER=your-email@gmail.com
 * EMAIL_PASS=your-app-password
 * EMAIL_FROM="StaffDesk <your-email@gmail.com>"
 */
const transporter = nodemailer.createTransport({
    host: process.env.EMAIL_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.EMAIL_PORT || '587'),
    secure: process.env.EMAIL_SECURE === 'true',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
    },
});

/**
 * Send welcome email to new employee with their login credentials.
 */
const sendWelcomeEmail = async ({ toEmail, employeeName, tempPassword }) => {
    const fromAddress = process.env.EMAIL_FROM || `"StaffDesk" <${process.env.EMAIL_USER}>`;
    const loginUrl = process.env.FRONTEND_URL || 'http://localhost:5173/login';
    const resetUrl = process.env.FRONTEND_URL ? `${process.env.FRONTEND_URL}/reset-password` : 'http://localhost:5173/reset-password';

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f8fafc; margin: 0; padding: 0; }
    .wrapper { max-width: 520px; margin: 40px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #6d28d9, #4f46e5); padding: 36px 40px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.5px; }
    .header p { color: rgba(255,255,255,0.8); margin: 8px 0 0; font-size: 14px; }
    .body { padding: 36px 40px; }
    .body p { color: #374151; line-height: 1.7; margin: 0 0 16px; }
    .creds-box { background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 10px; padding: 20px 24px; margin: 24px 0; }
    .creds-box .label { font-size: 11px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 4px; }
    .creds-box .value { font-size: 16px; font-weight: 700; color: #1e293b; font-family: monospace; }
    .creds-box .divider { height: 1px; background: #e2e8f0; margin: 14px 0; }
    .btn { display: inline-block; background: #6d28d9; color: white; text-decoration: none; padding: 14px 28px; border-radius: 10px; font-weight: 700; font-size: 15px; margin: 8px 0; }
    .footer { padding: 20px 40px; background: #f8fafc; border-top: 1px solid #f1f5f9; }
    .footer p { color: #94a3b8; font-size: 12px; margin: 0; text-align: center; }
    .warning { background: #fff7ed; border: 1px solid #fed7aa; border-radius: 8px; padding: 12px 16px; margin: 20px 0; font-size: 13px; color: #9a3412; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1>Welcome to StaffDesk</h1>
      <p>Your account has been created</p>
    </div>
    <div class="body">
      <p>Hi <strong>${employeeName}</strong>,</p>
      <p>Your account has been set up on the StaffDesk portal. Use the credentials below to sign in for the first time.</p>
      
      <div class="creds-box">
        <div class="label">Email Address</div>
        <div class="value">${toEmail}</div>
        <div class="divider"></div>
        <div class="label">Temporary Password</div>
        <div class="value">${tempPassword}</div>
      </div>

      <div class="warning">
        ⚠️ <strong>Important:</strong> This is a temporary password. Please change it immediately after your first login.
      </div>

      <center>
        <a href="${loginUrl}" class="btn">Sign In to Dashboard →</a>
      </center>

      <p style="margin-top: 24px; font-size: 13px; color: #64748b;">
        After logging in, change your password at <a href="${resetUrl}" style="color: #6d28d9;">${resetUrl}</a>
      </p>
    </div>
    <div class="footer">
      <p>This email was sent automatically by StaffDesk. If you did not expect this, please contact your HR department.</p>
    </div>
  </div>
</body>
</html>`;

    await transporter.sendMail({
        from: fromAddress,
        to: toEmail,
        subject: 'Welcome to StaffDesk — Your Login Credentials',
        html,
    });
};

/**
 * Send OTP email for password reset.
 */
const sendOTPEmail = async ({ toEmail, otp }) => {
    const fromAddress = process.env.EMAIL_FROM || `"StaffDesk" <${process.env.EMAIL_USER}>`;

    const html = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, sans-serif; background: #f8fafc; margin: 0; padding: 0; }
    .wrapper { max-width: 460px; margin: 40px auto; background: #fff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #6d28d9, #4f46e5); padding: 32px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 22px; font-weight: 800; }
    .body { padding: 36px 40px; text-align: center; }
    .otp { font-size: 42px; font-weight: 900; letter-spacing: 10px; color: #1e293b; font-family: monospace; margin: 24px 0; }
    .body p { color: #64748b; font-size: 14px; line-height: 1.6; }
    .footer { padding: 16px; background: #f8fafc; border-top: 1px solid #f1f5f9; }
    .footer p { color: #94a3b8; font-size: 11px; text-align: center; margin: 0; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header"><h1>Password Reset OTP</h1></div>
    <div class="body">
      <p>Use the code below to reset your StaffDesk password. This code expires in <strong>15 minutes</strong>.</p>
      <div class="otp">${otp}</div>
      <p>If you did not request this, ignore this email. Your password will not change.</p>
    </div>
    <div class="footer"><p>StaffDesk Security · This is an automated message</p></div>
  </div>
</body>
</html>`;

    await transporter.sendMail({
        from: fromAddress,
        to: toEmail,
        subject: 'Your StaffDesk Password Reset OTP',
        html,
    });
};

module.exports = { sendWelcomeEmail, sendOTPEmail };
