const express = require('express');
const request = require('supertest');
const alertsRoutes = require('../routes/alerts');

jest.mock('../models/User', () => ({
  findById: jest.fn(),
  save: jest.fn()
}));

jest.mock('../models/Circle', () => ({
  find: jest.fn()
}));

const app = express();
app.use(express.json());
app.use('/api/alerts', alertsRoutes);

describe('Alerts Routes', () => {
  const User = require('../models/User');
  const Circle = require('../models/Circle');

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('POST /api/alerts/speed - fails if user not found', async () => {
    User.findById.mockResolvedValueOnce(null);
    const res = await request(app).post('/api/alerts/speed').send({ userId: '123' });
    expect(res.statusCode).toBe(404);
  });

  it('POST /api/alerts/speed - returns cooldown message if active', async () => {
    User.findById.mockResolvedValueOnce({ lastSpeedAlert: new Date() });
    const res = await request(app).post('/api/alerts/speed').send({ userId: '123' });
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Cooldown active');
  });

  it('POST /api/alerts/risk - successful risk alert', async () => {
    const mockUser = { lastRiskAlert: new Date(Date.now() - 10 * 60 * 1000), save: jest.fn() };
    User.findById.mockResolvedValueOnce(mockUser);
    Circle.find.mockResolvedValueOnce([]);
    const res = await request(app).post('/api/alerts/risk').send({ userId: '123', lat: 10, lon: 10 });
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
