const axios = require('axios');

const SPRING_EMERGENCY_SERVICE_URL =
  process.env.SPRING_EMERGENCY_SERVICE_URL || 'http://localhost:8080';

async function publishEmergencyEvent(event) {
  const payload = {
    eventId: String(event.eventId),
    latitude: event.latitude,
    longitude: event.longitude,
    locationStatus: event.locationStatus || 'OK',
    locationAgeSec: event.locationAgeSec ?? null,
    severity: event.severity || 'HIGH',
    timestamp: event.timestamp || new Date().toISOString(),
  };

  const response = await axios.post(
    `${SPRING_EMERGENCY_SERVICE_URL}/api/sos`,
    payload,
    { timeout: 2500 }
  );
  return response.data;
}

module.exports = { publishEmergencyEvent };
