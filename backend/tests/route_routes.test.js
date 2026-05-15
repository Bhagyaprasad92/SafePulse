const express = require('express');
const request = require('supertest');
const routeRoutes = require('../routes/route_routes');
const axios = require('axios');

jest.mock('axios');
jest.mock('@mapbox/polyline', () => ({
  decode: jest.fn().mockReturnValue([[10, 10]])
}));

jest.mock('../services/risk_incident_repository', () => ({
  getRiskZonesForRoutes: jest.fn().mockResolvedValue([
    { lat: 10, lng: 10, radiusM: 1000, severity: 90, label: 'Test risk zone' }
  ])
}));

jest.mock('../middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    req.userId = 'mock_user_id';
    next();
  }
}));

const app = express();
app.use(express.json());
app.use('/api/routes', routeRoutes);

describe('Route Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('POST /api/routes/suggest - missing location data', async () => {
    const res = await request(app).post('/api/routes/suggest').send({});
    expect(res.statusCode).toBe(400);
  });

  it('POST /api/routes/suggest - successful request', async () => {
    axios.get.mockResolvedValueOnce({ 
      data: { 
        code: 'Ok',
        routes: [{
          geometry: { coordinates: [[10, 10], [20, 20]] },
          distance: 100, 
          duration: 10
        }] 
      } 
    });
    
    const res = await request(app).post('/api/routes/suggest').send({
      start: { lat: 10, lng: 10 },
      destination: { lat: 20, lng: 20 }
    });
    
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.routes.length).toBeGreaterThan(0);
  });
});

