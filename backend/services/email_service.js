const nodemailer = require('nodemailer');

const emailUser = process.env.EMAIL_USER;
const emailPass = process.env.EMAIL_PASS;

console.log('[EMAIL] Initialising with user:', emailUser ? 'Set' : 'NOT SET');
console.log('[EMAIL] Initialising with pass:', emailPass ? 'Set' : 'NOT SET');

const transporter = emailUser && emailPass
  ? nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: emailUser,
        pass: emailPass,
      },
    })
  : null;

if (!transporter) {
  console.warn('[EMAIL] Transporter is NULL. Falling back to DEV MODE logging.');
}

/**
 * Send OTP via Email
 */
exports.sendEmailOTP = async (email, otp) => {
  if (transporter) {
    const mailOptions = {
      from: `"SafePulse Support" <${emailUser}>`,
      to: email,
      subject: 'Your SafePulse Verification Code',
      text: `Your SafePulse verification code is: ${otp}. It is valid for 10 minutes.`,
      html: `
        <div style="font-family: Arial, sans-serif; color: #333;">
          <h2>SafePulse Verification</h2>
          <p>Your verification code is:</p>
          <h1 style="color: #6C63FF; letter-spacing: 5px;">${otp}</h1>
          <p>This code is valid for 10 minutes. If you didn't request this, please ignore this email.</p>
          <br/>
          <p>Stay safe,<br/>The SafePulse Team</p>
        </div>
      `,
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log(`[EMAIL] OTP sent to ${email}`);
      return true;
    } catch (error) {
      console.error('[EMAIL] Failed to send email:', error.message);
      return false;
    }
  } else {
    console.warn(`[EMAIL] DEV MODE — OTP for ${email}: ${otp}`);
    return true;
  }
};
