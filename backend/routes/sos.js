const express = require('express');
const router  = express.Router();
const User    = require('../models/User');
const SOS     = require('../models/SOS');
const notificationService = require('../services/notification_service');
const { requireAuth } = require('../middleware/auth');

// POST /api/sos/start  (protected)
router.post('/start', requireAuth, async (req, res) => {
  const userId = req.userId;
  const { lat, lng, address } = req.body;

  if (!lat || !lng) {
    return res.status(400).json({ message: 'lat and lng are required' });
  }

  try {
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    // 1. Find nearby users (requires locationPoint to be up-to-date via update-status)
    let nearbyUsers = [];
    try {
      nearbyUsers = await User.find({
        _id: { $ne: userId },
        locationPoint: {
          $near: {
            $geometry: { type: 'Point', coordinates: [Number(lng), Number(lat)] },
            $maxDistance: 5000, // Increased to 5km for better reach
          },
        },
      }).select('_id name fcmToken');
    } catch (dbErr) {
      console.error('[SOS] Nearby users query failed (missing index?):', dbErr.message);
      // Fallback: just get all users if geo query fails, or empty array
    }

    // 2. Create SOS record
    const sos = new SOS({
      victimId: userId,
      location: { lat, lng, address: address || 'Emergency Location' },
      contactsNotified: (user.emergencyContacts || []).map(c => ({
        name: c.name,
        phone: c.phone,
        status: 'PENDING',
      })),
      nearbyUsersNotified: (nearbyUsers || []).map(u => u._id),
    });
    await sos.save();

    // 3. SMS emergency contacts
    const mapUrl = `https://www.google.com/maps?q=${lat},${lng}`;
    const smsBody =
      `EMERGENCY! ${user.name} needs help.\n` +
      `Location: ${address || 'Unknown'}\n` +
      `Track here: ${mapUrl}\n` +
      `— SafePulse Safety App`;

    const smsPromises = (user.emergencyContacts || []).map(c =>
      notificationService.sendSMS(c.phone, smsBody).catch(err => console.error('[SOS] SMS fail:', err))
    );

    // 4. Push nearby users
    const fcmTokens = nearbyUsers.filter(u => u.fcmToken).map(u => u.fcmToken);
    const pushPromise = fcmTokens.length > 0
      ? notificationService.sendPushNotification(
          fcmTokens,
          '🚨 Emergency Nearby!',
          `${user.name} needs help. Tap to see location.`,
          { sosId: sos._id.toString(), lat: String(lat), lng: String(lng), type: 'SOS_ALERT' }
        ).catch(err => console.error('[SOS] Push fail:', err))
      : Promise.resolve();

    // Run notifications in background (non-blocking) to ensure instant SOS trigger
    Promise.allSettled([...smsPromises, pushPromise]).then(() => {
      // Update SOS contact statuses to SENT
      sos.contactsNotified = sos.contactsNotified.map(c => ({ ...c.toObject(), status: 'SENT' }));
      sos.save().catch(err => console.error('[SOS] Failed to save SENT status', err));
    });

    const realtimeHub = req.app.get('realtimeHub');
    if (realtimeHub?.isEnabled) {
      realtimeHub.broadcastSafetyEvent({
        type: 'circle:sos-alert',
        userIds: req.body.circleMemberIds || [],
        data: {
          sosId: sos._id,
          victimId: userId,
          location: { lat, lng, address: address || 'Emergency Location' },
          nearbyCount: nearbyUsers.length,
        },
      });
    }

    res.status(201).json({
      success: true,
      sosId: sos._id,
      nearbyCount: (nearbyUsers || []).length,
      contactsCount: (user.emergencyContacts || []).length,
    });
  } catch (error) {
    console.error('[SOS] start error:', error);
    res.status(500).json({ message: 'Failed to start SOS' });
  }
});

// POST /api/sos/cancel  (protected)
router.post('/cancel', requireAuth, async (req, res) => {
  const { sosId } = req.body;
  try {
    const sos = await SOS.findById(sosId);
    if (!sos) return res.status(404).json({ message: 'SOS not found' });
    if (sos.victimId.toString() !== req.userId) {
      return res.status(403).json({ message: 'Not authorised to cancel this SOS' });
    }
    sos.status = 'CANCELLED';
    sos.updatedAt = new Date();
    await sos.save();
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ message: 'Failed to cancel SOS' });
  }
});

// POST /api/sos/respond  (protected)
router.post('/respond', requireAuth, async (req, res) => {
  const { sosId } = req.body;
  const userId = req.userId;
  try {
    const sos = await SOS.findById(sosId);
    if (!sos) return res.status(404).json({ message: 'SOS not found' });
    const alreadyResponded = sos.responders.some(r => r.userId.toString() === userId);
    if (!alreadyResponded) {
      sos.responders.push({ userId });
      await sos.save();
    }
    res.json({ success: true, respondersCount: sos.responders.length });
  } catch (error) {
    res.status(500).json({ message: 'Failed to record response' });
  }
});

// GET /api/sos/:id  (protected)
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const sos = await SOS.findById(req.params.id)
      .populate('victimId', 'name phone')
      .populate('responders.userId', 'name phone');
    if (!sos) return res.status(404).json({ message: 'SOS not found' });
    res.json(sos);
  } catch (error) {
    res.status(500).json({ message: 'Failed to fetch SOS' });
  }
});

module.exports = router;
