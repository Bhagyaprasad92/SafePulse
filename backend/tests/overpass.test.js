const express = require('express');
const request = require('supertest');
const overpassRoutes = require('../routes/overpass');
const axios = require('axios');

jest.mock('axios');
jest.mock('../middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    req.userId = 'mock_user_id';
    next();
  }
}));

const app = express();
app.use(express.json());
app.use('/api/overpass', overpassRoutes);

describe('Overpass Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('GET /api/overpass/nearby - missing lat/lng', async () => {
    const res = await request(app).get('/api/overpass/nearby');
    expect(res.statusCode).toBe(400);
  });

  it('GET /api/overpass/nearby - valid request', async () => {
    axios.post.mockResolvedValue({ data: { elements: [] } });
    const res = await request(app).get('/api/overpass/nearby').query({ lat: 10, lng: 10 });
    expect(res.statusCode).toBe(200);
  });
});
