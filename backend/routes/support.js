const express = require('express');
const router = express.Router();
const nodemailer = require('nodemailer');
const { requireAuth } = require('../middleware/auth');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

// POST /api/support/contact  (protected)
router.post('/contact', requireAuth, async (req, res) => {
  const { name, phone, loginType, subject, message } = req.body;

  if (!message || message.trim().length < 10) {
    return res.status(400).json({ message: 'Message must be at least 10 characters.' });
  }

  const mailOptions = {
    from: `"SafePulse App" <${process.env.EMAIL_USER}>`,
    to: process.env.EMAIL_USER, // sends support emails to same account (your inbox)
    replyTo: process.env.EMAIL_USER,
    subject: subject || 'SafePulse Support Request',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
        <div style="background: #1565C0; padding: 24px; text-align: center;">
          <h1 style="color: white; margin: 0;">SafePulse Support</h1>
        </div>
        <div style="padding: 24px;">
          <h2 style="color: #333;">New Support Request</h2>
          <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
            <tr><td style="padding: 8px; font-weight: bold; color: #555; width: 120px;">Name</td><td style="padding: 8px; color: #333;">${name || 'N/A'}</td></tr>
            <tr style="background: #f9f9f9;"><td style="padding: 8px; font-weight: bold; color: #555;">Phone</td><td style="padding: 8px; color: #333;">${phone || 'N/A'}</td></tr>
            <tr><td style="padding: 8px; font-weight: bold; color: #555;">Login Type</td><td style="padding: 8px; color: #333;">${loginType || 'N/A'}</td></tr>
          </table>
          <h3 style="color: #555;">Message</h3>
          <div style="background: #f5f5f5; padding: 16px; border-radius: 6px; color: #333; line-height: 1.6;">
            ${message.replace(/\n/g, '<br>')}
          </div>
        </div>
        <div style="background: #f5f5f5; padding: 16px; text-align: center; color: #999; font-size: 12px;">
          Sent from SafePulse Mobile App
        </div>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    res.json({ success: true, message: 'Support email sent successfully.' });
  } catch (error) {
    console.error('[SUPPORT] Email send error:', error.message);
    res.status(500).json({ message: 'Failed to send email. Please try again.' });
  }
});

module.exports = router;
