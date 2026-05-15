const express = require('express');
const router = express.Router();
const User = require('../models/User');
const twilio = require('twilio');
const { signToken, requireAuth } = require('../middleware/auth');
const emailService = require('../services/email_service');

const accountSid  = process.env.TWILIO_ACCOUNT_SID;
const authToken   = process.env.TWILIO_AUTH_TOKEN;
const twilioPhone = process.env.TWILIO_PHONE_NUMBER;

const client =
  accountSid && accountSid.startsWith('AC') && authToken
    ? twilio(accountSid, authToken)
    : null;


router.post('/send-otp', async (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ success: false, error: 'Phone number is required' });

  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const otpExpiry = new Date(Date.now() + 10 * 60000); // 10 minutes

  try {
    let user = await User.findOne({ phone });
    if (!user) {
      user = new User({ phone, name: 'SafePulse User', otp, otpExpiry, loginType: 'phone' });
    } else {
      user.otp = otp;
      user.otpExpiry = otpExpiry;
      user.loginType = 'phone';
    }
    await user.save();

    if (client && twilioPhone) {
      await client.messages.create({
        body: `Your SafePulse verification code is: ${otp}. Valid for 10 minutes.`,
        from: twilioPhone,
        to: phone,
      });
      console.log(`[AUTH] OTP sent to ${phone}`);
    } else {
      // Dev mode: log OTP so developer can test without Twilio
      console.warn(`[AUTH] DEV MODE — OTP for ${phone}: ${otp}`);
    }

    res.json({ success: true, message: 'OTP sent successfully' });
  } catch (error) {
    console.error('[AUTH] send-otp error:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.post('/send-email-otp', async (req, res) => {
  const { email, name, phone } = req.body;
  console.log(`[AUTH] send-email-otp request: email=${email}, name=${name}, phone=${phone}`);
  if (!email) return res.status(400).json({ success: false, error: 'Email is required' });

  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const otpExpiry = new Date(Date.now() + 10 * 60000);

  try {
    let user = await User.findOne({ email });
    if (!user) {
      if (!phone || !name) {
        console.log('[AUTH] Missing name/phone for new registration');
        return res.status(400).json({ success: false, error: 'Name and Phone are required for new registration' });
      }
      user = new User({ email, phone, name, otp, otpExpiry, loginType: 'email' });
      console.log('[AUTH] Creating new user for email:', email);
    } else {
      user.otp = otp;
      user.otpExpiry = otpExpiry;
      user.loginType = 'email';
      if (name) user.name = name;
      if (phone) user.phone = phone;
      console.log('[AUTH] Existing user found, updating OTP for:', email);
    }
    await user.save();
    console.log('[AUTH] User saved. Sending email OTP...');

    const sent = await emailService.sendEmailOTP(email, otp);
    console.log('[AUTH] Email send result:', sent);
    if (!sent) return res.status(500).json({ success: false, error: 'Failed to send verification email' });

    console.log(`[AUTH] ✅ OTP sent to ${email}: ${otp}`);
    res.json({ success: true, message: 'Verification code sent to your email' });
  } catch (error) {
    console.error('[AUTH] send-email-otp error:', error.message);
    console.error('[AUTH] Full error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.post('/verify-otp', async (req, res) => {
  const { phone, email, otp } = req.body;

  try {
    const query = email ? { email } : { phone };
    const user = await User.findOne(query);
    if (!user) return res.status(404).json({ success: false, error: 'User not found' });

    if (user.otp !== otp) {
      return res.status(400).json({ success: false, error: 'Invalid OTP' });
    }
    if (user.otpExpiry && new Date() > user.otpExpiry) {
      return res.status(400).json({ success: false, error: 'OTP has expired. Please request a new one.' });
    }

    user.otp = undefined;
    user.otpExpiry = undefined;
    await user.save();

    const token = signToken(user._id.toString());

    console.log(`[AUTH] Login successful: ${user._id}`);
    res.json({
      success: true,
      token,
      user: {
        _id: user._id,
        name: user.name,
        phone: user.phone,
        email: user.email || '',
        loginType: user.loginType,
        emergencyContacts: user.emergencyContacts,
      },
    });
  } catch (error) {
    console.error('[AUTH] verify-otp error:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.post('/update-status', requireAuth, async (req, res) => {
  const { location, batteryLevel, isDriving, currentSpeed, fcmToken } = req.body;
  const userId = req.userId;

  try {
    const update = {
      lastSeen: new Date(),
    };

    if (location) {
      update.location = location;
      // Keep the GeoJSON Point in sync so MongoDB $near queries work
      update.locationPoint = {
        type: 'Point',
        coordinates: [location.lng, location.lat], // MongoDB: [lng, lat] order
      };
    }
    if (batteryLevel !== undefined) update.batteryLevel = batteryLevel;
    if (isDriving     !== undefined) update.isDriving   = isDriving;
    if (currentSpeed  !== undefined) update.currentSpeed = currentSpeed;
    if (fcmToken)                    update.fcmToken    = fcmToken;

    const user = await User.findByIdAndUpdate(userId, update, { new: true });
    if (!user) return res.status(404).json({ success: false, error: 'User not found' });

    res.json({ success: true });
  } catch (error) {
    console.error('[AUTH] update-status error:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});


router.patch('/update-name', requireAuth, async (req, res) => {
  const { name } = req.body;
  if (!name || name.trim().length < 2) {
    return res.status(400).json({ success: false, error: 'Name too short' });
  }
  try {
    await User.findByIdAndUpdate(req.userId, { name: name.trim() });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});


router.get('/me', requireAuth, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-otp -otpExpiry -fcmToken');
    if (!user) return res.status(404).json({ success: false, error: 'User not found' });
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});


router.post('/emergency-contacts', requireAuth, async (req, res) => {
  const { contacts } = req.body; // [{name, phone, relation}]
  try {
    await User.findByIdAndUpdate(req.userId, { emergencyContacts: contacts });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
