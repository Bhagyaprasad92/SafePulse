const routeScoring = require('../services/route_scoring');

describe('Route Scoring Service', () => {
  it('scores points higher when they are inside a severe risk zone', () => {
    const zones = [{ lat: 17.385, lng: 78.4867, radiusM: 1000, severity: 90 }];

    const centerScore = routeScoring.pointRiskScore(17.385, 78.4867, zones);
    const farScore = routeScoring.pointRiskScore(17.5, 78.6, zones);

    expect(centerScore).toBeGreaterThan(80);
    expect(farScore).toBe(0);
  });

  it('returns deterministic safest-first route suggestions', () => {
    const zones = [{ lat: 10, lng: 10, radiusM: 1000, severity: 90 }];
    const routes = [
      { id: 'r1', duration: 100, distance: 1000, polyline: [[10, 10]] },
      { id: 'r2', duration: 120, distance: 1200, polyline: [[11, 11]] }
    ];

    const scored = routeScoring.scoreRoutes(routes, zones);

    expect(scored[0].id).toBe('r2');
    expect(scored[1].id).toBe('r1');
  });
});
