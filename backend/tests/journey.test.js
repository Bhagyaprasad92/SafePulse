const express = require('express');
const request = require('supertest');
const journeyRoutes = require('../routes/journey');

jest.mock('../services/safety_engine', () => ({
  evaluateSafety: jest.fn().mockReturnValue({ status: 'SAFE', warningSent: false, circleNotified: false }),
  clearState: jest.fn()
}));

jest.mock('../services/notification_service', () => ({
  sendToUser: jest.fn().mockResolvedValue(true),
  broadcastToCircle: jest.fn().mockResolvedValue(true)
}));

jest.mock('../middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    req.userId = 'mock_user_id';
    next();
  }
}));

const app = express();
app.use(express.json());
app.use('/api/journey', journeyRoutes);

describe('Journey Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('POST /api/journey/update - successful update', async () => {
    const res = await request(app).post('/api/journey/update').send({ speed: 10, isPhoneOn: true });
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('POST /api/journey/end - successful end', async () => {
    const res = await request(app).post('/api/journey/end').send({});
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
