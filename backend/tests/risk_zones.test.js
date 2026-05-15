const express = require('express');
const request = require('supertest');
const riskZoneRoutes = require('../routes/risk_zones');

jest.mock('../middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    req.userId = 'mock_user_id';
    next();
  }
}));

jest.mock('../services/risk_incident_repository', () => ({
  listRiskZones: jest.fn().mockResolvedValue([
    { id: 'zone-1', lat: 17, lng: 78, radiusM: 500, severity: 80, label: 'Test zone' }
  ]),
  createRiskIncident: jest.fn().mockResolvedValue({
    id: 'zone-2',
    lat: 17,
    lng: 78,
    radiusM: 800,
    severity: 90,
    label: 'New zone'
  })
}));

const app = express();
app.use(express.json());
app.use('/api/risk-zones', riskZoneRoutes);

describe('Risk Zone Routes', () => {
  it('GET /api/risk-zones - returns dynamic risk zone source data', async () => {
    const res = await request(app).get('/api/risk-zones');

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.count).toBe(1);
  });

  it('POST /api/risk-zones - creates a new incident-backed risk zone', async () => {
    const res = await request(app).post('/api/risk-zones').send({
      lat: 17,
      lng: 78,
      severity: 90,
      label: 'New zone'
    });

    expect(res.statusCode).toBe(201);
    expect(res.body.riskZone.label).toBe('New zone');
  });
});
