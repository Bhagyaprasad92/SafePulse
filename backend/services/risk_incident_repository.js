const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const RiskIncident = require('../models/RiskIncident');

const DEFAULT_SEED_PATH = path.join(__dirname, '..', 'data', 'risk_zones.json');

function normalizeZone(zone) {
  if (!zone) return null;

  const coordinates = zone.locationPoint?.coordinates;
  const lng = zone.lng ?? coordinates?.[0];
  const lat = zone.lat ?? coordinates?.[1];

  if (!Number.isFinite(Number(lat)) || !Number.isFinite(Number(lng))) return null;

  return {
    id: String(zone._id || zone.id || `${lat}:${lng}:${zone.label || 'risk-zone'}`),
    lat: Number(lat),
    lng: Number(lng),
    radiusM: Number(zone.radiusM || 500),
    severity: Number(zone.severity || 0),
    label: zone.label || zone.category || 'Risk zone',
    category: zone.category || 'COMMUNITY_REPORT',
    source: zone.source || 'database',
    updatedAt: zone.updatedAt || zone.createdAt || null,
  };
}

function readSeedRiskZones(seedPath = process.env.RISK_ZONE_DATA_PATH || DEFAULT_SEED_PATH) {
  const raw = fs.readFileSync(seedPath, 'utf8');
  return JSON.parse(raw)
    .map(normalizeZone)
    .filter(Boolean);
}

function uniqueZones(zones) {
  const byId = new Map();
  for (const zone of zones) {
    byId.set(zone.id, zone);
  }
  return [...byId.values()];
}

function sampleRoutePoints(polylinePoints, maxSamples = 8) {
  if (!Array.isArray(polylinePoints) || polylinePoints.length === 0) return [];
  const step = Math.max(1, Math.floor(polylinePoints.length / maxSamples));
  return polylinePoints.filter((_, index) => index % step === 0).slice(0, maxSamples);
}

async function queryMongoRiskZones(polylinePoints, maxDistanceM = 2500) {
  if (mongoose.connection.readyState !== 1) return [];

  const sampled = sampleRoutePoints(polylinePoints);
  const results = [];

  for (const [lat, lng] of sampled) {
    const incidents = await RiskIncident.find({
      active: true,
      $or: [{ expiresAt: null }, { expiresAt: { $gt: new Date() } }],
      locationPoint: {
        $near: {
          $geometry: { type: 'Point', coordinates: [lng, lat] },
          $maxDistance: maxDistanceM,
        },
      },
    }).limit(20).lean();

    results.push(...incidents.map(normalizeZone).filter(Boolean));
  }

  return uniqueZones(results);
}

async function getRiskZonesForRoutes(routes) {
  const routePoints = routes.flatMap(route => route.polyline || []);
  const databaseZones = await queryMongoRiskZones(routePoints);
  const seedZones = readSeedRiskZones();

  return uniqueZones([...databaseZones, ...seedZones]);
}

async function listRiskZones() {
  const seedZones = readSeedRiskZones();
  if (mongoose.connection.readyState !== 1) return seedZones;

  const incidents = await RiskIncident.find({
    active: true,
    $or: [{ expiresAt: null }, { expiresAt: { $gt: new Date() } }],
  }).lean();

  return uniqueZones([
    ...incidents.map(normalizeZone).filter(Boolean),
    ...seedZones,
  ]);
}

async function createRiskIncident(payload) {
  const lat = Number(payload.lat);
  const lng = Number(payload.lng);

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    const error = new Error('lat and lng must be valid numbers');
    error.statusCode = 400;
    throw error;
  }

  const incident = new RiskIncident({
    label: payload.label,
    category: payload.category,
    severity: payload.severity,
    radiusM: payload.radiusM,
    source: payload.source || 'api',
    active: payload.active !== false,
    locationPoint: { type: 'Point', coordinates: [lng, lat] },
    expiresAt: payload.expiresAt,
  });

  await incident.save();
  return normalizeZone(incident.toObject());
}

module.exports = {
  createRiskIncident,
  getRiskZonesForRoutes,
  listRiskZones,
  normalizeZone,
  readSeedRiskZones,
};
