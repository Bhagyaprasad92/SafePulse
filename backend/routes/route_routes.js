const express = require('express');
const router = express.Router();
const axios = require('axios');
const routeScoring = require('../services/route_scoring');
const riskIncidentRepository = require('../services/risk_incident_repository');
const { requireAuth } = require('../middleware/auth');

function isValidCoordinatePair(point) {
  return Number.isFinite(Number(point?.lat)) && Number.isFinite(Number(point?.lng));
}

router.post('/suggest', requireAuth, async (req, res) => {
  try {
    const { start, destination, alternatives = 3 } = req.body;

    if (!isValidCoordinatePair(start) || !isValidCoordinatePair(destination)) {
      return res.status(400).json({
        error: 'Start and destination coordinates (lat, lng) are required and must be valid numbers',
      });
    }

    console.log(`Route request: [${start.lat}, ${start.lng}] -> [${destination.lat}, ${destination.lng}]`);

    const routes = await fetchRoutesFromOSRM(start, destination, alternatives);
    if (!routes || routes.length === 0) {
      return res.status(404).json({ error: 'No routes found for the given coordinates' });
    }

    console.log(`Fetched ${routes.length} routes from OSRM`);

    const riskZones = await riskIncidentRepository.getRiskZonesForRoutes(routes);
    const scoredRoutes = routeScoring.scoreRoutes(routes, riskZones);

    const response = {
      success: true,
      start,
      destination,
      routeCount: scoredRoutes.length,
      riskZoneCount: riskZones.length,
      routes: scoredRoutes.map((route, index) => formatRoute(route, index, riskZones.length)),
    };

    console.log('\n=== Route Analysis Summary ===');
    scoredRoutes.forEach((route, index) => {
      const safetyScore = Math.max(0, 100 - route.riskScore);
      console.log(
        `Route ${index + 1}: Safety=${safetyScore}/100, ` +
        `Distance=${(route.distance / 1000).toFixed(1)}km, ` +
        `Duration=${Math.round(route.duration / 60)}min`
      );
    });

    res.json(response);
  } catch (error) {
    console.error('Error in /api/routes/suggest:', error);
    res.status(500).json({
      error: 'Failed to generate route suggestions',
      message: error.message,
    });
  }
});

function formatRoute(route, index, riskZoneCount) {
  const safetyScore = Math.max(0, 100 - route.riskScore);
  const warning =
    route.riskScore > 65
      ? 'Route crosses a high-risk incident zone'
      : route.riskScore > 30
        ? 'Route crosses moderate-risk incident data'
        : null;

  return {
    id: route.id,
    type: route.label,
    color: route.color,
    rank: index + 1,
    recommended: index === 0,
    distance: route.distance,
    distanceKm: (route.distance / 1000).toFixed(2),
    duration: route.duration,
    durationMin: Math.round(route.duration / 60),
    safetyScore,
    safetyLevel: route.label.toLowerCase(),
    riskScore: route.riskScore,
    actualRiskScore: route.riskScore,
    safetyBreakdown: {
      sampledRiskZones: riskZoneCount,
      scoreSource: 'mongodb-risk-incidents-plus-seed-zones',
      synthetic: Boolean(route.synthetic),
    },
    warnings: warning ? [{
      type: 'risk_zone',
      severity: route.riskScore > 65 ? 'high' : 'medium',
      message: warning,
    }] : [],
    recommendations: index === 0 ? [{
      priority: 'high',
      message: 'Recommended safest route',
      reason: 'Lowest risk score from incident-backed safety model',
    }] : [],
    polyline: route.polyline,
    points: route.points,
  };
}

async function fetchRoutesFromOSRM(start, destination, alternativeCount = 3) {
  try {
    const coords = `${start.lng},${start.lat};${destination.lng},${destination.lat}`;
    const osrmUrl =
      `http://router.project-osrm.org/route/v1/driving/${coords}` +
      '?overview=full&geometries=geojson&steps=false&alternatives=true';

    const response = await axios.get(osrmUrl, { timeout: 10000 });
    if (
      response.data.code !== 'Ok' ||
      !response.data.routes ||
      response.data.routes.length === 0
    ) {
      console.log(`[OSRM] Failed or returned no routes: ${response.data.code}`);
      return [];
    }

    const routes = response.data.routes.map((route, index) => {
      const coordinates = route.geometry.coordinates;
      const polyline = coordinates.map(coord => [coord[1], coord[0]]);
      const points = coordinates.map(coord => ({ lat: coord[1], lon: coord[0] }));

      return {
        id: `route_${index + 1}`,
        points,
        polyline,
        distance: route.distance || 0,
        duration: route.duration || 0,
        metadata: { roadType: 'mixed' },
      };
    });

    while (routes.length < alternativeCount && routes.length > 0) {
      const baseRoute = routes[0];
      routes.push({
        ...baseRoute,
        id: `route_${routes.length + 1}`,
        distance: baseRoute.distance * (1 + routes.length * 0.05),
        duration: baseRoute.duration * (1 + routes.length * 0.05),
      });
    }

    return routes.slice(0, alternativeCount);
  } catch (error) {
    console.error('Error fetching routes from OSRM:', error.message);
    return [{
      id: 'route_direct',
      points: [
        { lat: start.lat, lon: start.lng },
        { lat: destination.lat, lon: destination.lng },
      ],
      polyline: [
        [start.lat, start.lng],
        [destination.lat, destination.lng],
      ],
      distance: calculateDirectDistance(start, destination),
      duration: 0,
      metadata: { roadType: 'direct' },
    }];
  }
}

function calculateDirectDistance(start, destination) {
  const earthRadiusM = 6371e3;
  const toRad = value => (value * Math.PI) / 180;
  const lat1 = toRad(start.lat);
  const lat2 = toRad(destination.lat);
  const deltaLat = toRad(destination.lat - start.lat);
  const deltaLng = toRad(destination.lng - start.lng);

  const a =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) *
    Math.sin(deltaLng / 2) * Math.sin(deltaLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusM * c;
}

module.exports = router;
