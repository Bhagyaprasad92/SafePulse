const express = require('express');
const router  = express.Router();
const safetyEngine       = require('../services/safety_engine');
const notificationService = require('../services/notification_service');
const { requireAuth }    = require('../middleware/auth');

router.post('/update', requireAuth, async (req, res) => {
  const { speed, isPhoneOn, userToken, circleTokens } = req.body;
  const userId = req.userId;

  try {
    const result = safetyEngine.evaluateSafety(userId, speed || 0, isPhoneOn || false);

    if (result.warningSent && userToken) {
      await notificationService.sendToUser(userToken, 'Safety Warning', result.message);
    }
    if (result.circleNotified && circleTokens?.length) {
      await notificationService.broadcastToCircle(circleTokens, 'Emergency Alert', result.message);
    }

    const realtimeHub = req.app.get('realtimeHub');
    if (realtimeHub?.isEnabled && (result.warningSent || result.circleNotified)) {
      realtimeHub.broadcastSafetyEvent({
        type: result.circleNotified ? 'circle:safety-alert' : 'user:safety-warning',
        userIds: req.body.circleMemberIds || [],
        data: {
          userId,
          status: result.status,
          message: result.message,
          speed,
          sentBy: 'journey-rest-fallback',
        },
      });
    }

    res.json({
      success: true,
      status:  result.status,
      message: result.message || 'Tracking active',
    });
  } catch (error) {
    console.error('[JOURNEY] error:', error.message);
    res.status(500).json({ success: false, error: 'Internal error' });
  }
});


router.post('/end', requireAuth, async (req, res) => {
  const safetyEngine = require('../services/safety_engine');
  safetyEngine.clearState(req.userId);
  res.json({ success: true });
});

module.exports = router;
