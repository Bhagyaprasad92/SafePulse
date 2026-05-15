const axios = require('axios');

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:7000';

async function analyzeAccident(payload) {
  const response = await axios.post(
    `${AI_SERVICE_URL}/v1/accident/analyze`,
    payload,
    { timeout: 3500 }
  );

  return response.data;
}

async function getModelMetadata() {
  const response = await axios.get(
    `${AI_SERVICE_URL}/v1/model/metadata`,
    { timeout: 2000 }
  );

  return response.data;
}

module.exports = { analyzeAccident, getModelMetadata };
