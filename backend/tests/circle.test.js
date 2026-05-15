const express = require('express');
const request = require('supertest');
const circleRoutes = require('../routes/circle');

jest.mock('../models/Circle', () => ({
  findOne: jest.fn(),
  findById: jest.fn()
}));

jest.mock('../models/User', () => ({
  findByIdAndUpdate: jest.fn(),
  findById: jest.fn()
}));

jest.mock('../middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    req.userId = 'mock_user_id';
    next();
  }
}));

const app = express();
app.use(express.json());
app.use('/api/circle', circleRoutes);

describe('Circle Routes', () => {
  const Circle = require('../models/Circle');
  const User = require('../models/User');

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('POST /api/circle/create - requires name', async () => {
    const res = await request(app).post('/api/circle/create').send({});
    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
  });

  it('POST /api/circle/join - invalid invite code', async () => {
    Circle.findOne.mockResolvedValueOnce(null);
    const res = await request(app).post('/api/circle/join').send({ inviteCode: 'INVALID' });
    expect(res.statusCode).toBe(404);
    expect(res.body.success).toBe(false);
  });

  it('GET /api/circle/my - fetches user circles', async () => {
    User.findById.mockReturnValueOnce({ populate: jest.fn().mockResolvedValueOnce({ circles: [] }) });
    const res = await request(app).get('/api/circle/my');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });
  
  it('PUT /api/circle/update-location - missing lat/lng', async () => {
    const res = await request(app).put('/api/circle/update-location').send({});
    expect(res.statusCode).toBe(400);
  });
});
