const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const riskIncidentRepository = require('../services/risk_incident_repository');

router.get('/', requireAuth, async (req, res) => {
  try {
    const riskZones = await riskIncidentRepository.listRiskZones();
    res.json({ success: true, count: riskZones.length, riskZones });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Failed to load risk zones' });
  }
});

router.post('/', requireAuth, async (req, res) => {
  try {
    const riskZone = await riskIncidentRepository.createRiskIncident(req.body);
    res.status(201).json({ success: true, riskZone });
  } catch (error) {
    res.status(error.statusCode || 500).json({
      success: false,
      message: error.message || 'Failed to create risk zone',
    });
  }
});

module.exports = router;
