/**
 * Scores candidate routes against risk zones supplied by the repository layer.
 * The scoring logic is deterministic and pure; data can come from MongoDB,
 * seed JSON, or future external incident feeds.
 */

function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = d => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function pointRiskScore(lat, lng, riskZones = []) {
  let maxScore = 0;

  for (const zone of riskZones) {
    const dist = haversineMeters(lat, lng, zone.lat, zone.lng);
    if (dist <= zone.radiusM) {
      const proximity = 1 - dist / zone.radiusM;
      const contribution = zone.severity * proximity;
      if (contribution > maxScore) maxScore = contribution;
    }
  }

  return maxScore;
}

function routeRiskScore(polylinePoints, riskZones = [], samples = 20) {
  if (!polylinePoints || polylinePoints.length === 0) return 0;

  const step = Math.max(1, Math.floor(polylinePoints.length / samples));
  let totalRisk = 0;
  let count = 0;

  for (let i = 0; i < polylinePoints.length; i += step) {
    const [lat, lng] = polylinePoints[i];
    totalRisk += pointRiskScore(lat, lng, riskZones);
    count++;
  }

  return Math.round(totalRisk / count);
}

function riskLabel(score) {
  if (score <= 30) return { type: 'SAFEST', color: 'green', label: 'Safest' };
  if (score <= 65) return { type: 'BALANCED', color: 'yellow', label: 'Balanced' };
  return { type: 'RISKY', color: 'red', label: 'Risky' };
}

function createSyntheticVariant(base, index) {
  const syntheticScore = Math.min(100, base.riskScore + 20 + index * 7);
  const { type, color, label } = riskLabel(syntheticScore);

  return {
    id: `r${index + 1}`,
    duration: Math.round(base.duration * (1 - 0.08 * Math.max(0, 3 - index))),
    distance: Math.round(base.distance * (1 - 0.06 * Math.max(0, 3 - index))),
    polyline: base.polyline,
    riskScore: syntheticScore,
    type,
    color,
    label,
    synthetic: true,
  };
}

function scoreRoutes(routes, riskZones = []) {
  const scored = routes.map(route => {
    const score = routeRiskScore(route.polyline, riskZones);
    const { type, color, label } = riskLabel(score);
    return {
      ...route,
      riskScore: score,
      type,
      color,
      label,
    };
  });

  scored.sort((a, b) => a.riskScore - b.riskScore);

  while (scored.length > 0 && scored.length < 3) {
    scored.push(createSyntheticVariant(scored[scored.length - 1], scored.length));
  }

  return scored.slice(0, 3);
}

module.exports = {
  haversineMeters,
  pointRiskScore,
  riskLabel,
  routeRiskScore,
  scoreRoutes,
};
