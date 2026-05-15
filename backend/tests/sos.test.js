const express = require('express');
const request = require('supertest');
const sosRoutes = require('../routes/sos');

jest.mock('../models/SOS', () => {
  function MockSOS(payload) {
    Object.assign(this, payload);
    this._id = 'sos_123';
    this.contactsNotified = payload.contactsNotified || [];
    this.save = jest.fn().mockResolvedValue(this);
  }
  MockSOS.findById = jest.fn();
  return MockSOS;
});

jest.mock('../models/User', () => ({
  findById: jest.fn(),
  find: jest.fn()
}));

jest.mock('../services/notification_service', () => ({
  sendSMS: jest.fn().mockResolvedValue(true),
  sendPushNotification: jest.fn().mockResolvedValue(true)
}));

jest.mock('../services/emergency_event_client', () => ({
  publishEmergencyEvent: jest.fn().mockResolvedValue({ eventId: 'spring_123' })
}));

jest.mock('../middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    req.userId = 'mock_user_id';
    next();
  }
}));

const app = express();
app.use(express.json());
app.use('/api/sos', sosRoutes);

describe('SOS Routes', () => {
  const User = require('../models/User');
  const SOS = require('../models/SOS');

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('POST /api/sos/start - missing location', async () => {
    const res = await request(app).post('/api/sos/start').send({});
    expect(res.statusCode).toBe(400);
  });

  it('POST /api/sos/start - user not found', async () => {
    User.findById.mockResolvedValueOnce(null);
    const res = await request(app).post('/api/sos/start').send({ lat: 10, lng: 10 });
    expect(res.statusCode).toBe(404);
  });

  it('POST /api/sos - creates gateway SOS and syncs Spring emergency event', async () => {
    const user = {
      _id: 'mock_user_id',
      name: 'Test User',
      emergencyContacts: [{ name: 'Guardian', phone: '+911234567890' }]
    };
    User.findById.mockResolvedValueOnce(user);
    User.find.mockReturnValueOnce({
      select: jest.fn().mockResolvedValueOnce([])
    });

    const res = await request(app).post('/api/sos').send({
      lat: 10,
      lng: 10,
      severity: 'HIGH',
      eventId: 'event-1'
    });

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.springEmergencySync).toBe(true);
  });

  it('POST /api/sos/cancel - sos not found', async () => {
    SOS.findById.mockResolvedValueOnce(null);
    const res = await request(app).post('/api/sos/cancel').send({ sosId: '123' });
    expect(res.statusCode).toBe(404);
  });
  
  it('POST /api/sos/respond - sos not found', async () => {
    SOS.findById.mockResolvedValueOnce(null);
    const res = await request(app).post('/api/sos/respond').send({ sosId: '123' });
    expect(res.statusCode).toBe(404);
  });
});
