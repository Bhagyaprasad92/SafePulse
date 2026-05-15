const express = require('express');
const request = require('supertest');
const axios = require('axios');
const aiRoutes = require('../routes/ai');

jest.mock('axios');
jest.mock('../middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    req.userId = 'mock_user_id';
    next();
  }
}));

const app = express();
app.use(express.json());
app.use('/api/ai', aiRoutes);

describe('AI Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('POST /api/ai/accident/analyze - rejects empty samples', async () => {
    const res = await request(app).post('/api/ai/accident/analyze').send({ samples: [] });
    expect(res.statusCode).toBe(400);
  });

  it('POST /api/ai/accident/analyze - proxies analysis to Python service', async () => {
    axios.post.mockResolvedValueOnce({
      data: { crashDetected: true, crashProbability: 0.91, severity: 'CRITICAL' }
    });

    const res = await request(app)
      .post('/api/ai/accident/analyze')
      .send({ samples: [{ ax: 30, ay: 5, az: 10, speedKmh: 45 }] });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.analysis.crashDetected).toBe(true);
    expect(axios.post).toHaveBeenCalledWith(
      expect.stringContaining('/v1/accident/analyze'),
      expect.objectContaining({ userId: 'mock_user_id' }),
      expect.objectContaining({ timeout: 3500 })
    );
  });
});
