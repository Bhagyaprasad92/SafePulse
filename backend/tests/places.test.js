const express = require('express');
const request = require('supertest');
const placesRoutes = require('../routes/places');
const axios = require('axios');

jest.mock('axios');

const app = express();
app.use(express.json());
app.use('/api/places', placesRoutes);

describe('Places Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('GET /api/places/search - query too short', async () => {
    const res = await request(app).get('/api/places/search').query({ q: 'a' });
    expect(res.statusCode).toBe(400);
  });

  it('GET /api/places/search - valid query', async () => {
    axios.get.mockResolvedValueOnce({ data: [] });
    const res = await request(app).get('/api/places/search').query({ q: 'hospital' });
    expect(res.statusCode).toBe(200);
  });
});
