const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const aiAccidentClient = require('../services/ai_accident_client');

router.get('/model', requireAuth, async (req, res) => {
  try {
    const model = await aiAccidentClient.getModelMetadata();
    res.json({ success: true, model });
  } catch (error) {
    res.status(502).json({ success: false, message: 'AI service unavailable' });
  }
});

router.post('/accident/analyze', requireAuth, async (req, res) => {
  const { samples, tripId } = req.body;
  if (!Array.isArray(samples) || samples.length === 0) {
    return res.status(400).json({ success: false, message: 'samples must be a non-empty array' });
  }

  try {
    const analysis = await aiAccidentClient.analyzeAccident({
      tripId,
      userId: req.userId,
      samples,
    });

    const realtimeHub = req.app.get('realtimeHub');
    if (analysis.crashDetected && realtimeHub?.isEnabled) {
      realtimeHub.broadcastSafetyEvent({
        type: 'circle:ai-crash-alert',
        userIds: req.body.circleMemberIds || [],
        data: { userId: req.userId, tripId, analysis },
      });
    }

    res.json({ success: true, analysis });
  } catch (error) {
    res.status(502).json({ success: false, message: 'AI accident analysis failed' });
  }
});

module.exports = router;
