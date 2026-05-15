const express = require('express');
const request = require('supertest');
const servicesRoutes = require('../routes/services');
const axios = require('axios');

jest.mock('axios');

const app = express();
app.use(express.json());
app.use('/api/services', servicesRoutes);

describe('Services Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('GET /api/services/nearby - missing coordinates', async () => {
    const res = await request(app).get('/api/services/nearby');
    expect(res.statusCode).toBe(400);
  });

  it('GET /api/services/nearby - valid coordinates', async () => {
    axios.get.mockResolvedValueOnce({ data: { elements: [] } });
    const res = await request(app).get('/api/services/nearby').query({ lat: 10, lon: 10 });
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('GET /api/services/bbox - missing bbox parameters', async () => {
    const res = await request(app).get('/api/services/bbox');
    expect(res.statusCode).toBe(400);
  });

  it('GET /api/services/bbox - valid bbox', async () => {
    axios.get.mockResolvedValueOnce({ data: { elements: [] } });
    const res = await request(app).get('/api/services/bbox').query({ south: 10, west: 10, north: 11, east: 11, type: 'hospital' });
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
