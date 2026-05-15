const express = require('express');
const router  = express.Router();
const axios   = require('axios');
const { requireAuth } = require('../middleware/auth');

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';
const SEARCH_RADIUS_M = 2000; // 2 km

// Build Overpass QL query for a given amenity type within a radius.
function buildQuery(lat, lng, amenity, radiusM) {
  return `
    [out:json][timeout:20];
    (
      node[amenity=${amenity}](around:${radiusM},${lat},${lng});
      way[amenity=${amenity}](around:${radiusM},${lat},${lng});
      relation[amenity=${amenity}](around:${radiusM},${lat},${lng});
    );
    out center tags;
  `.trim();
}

// Parse Overpass results into a clean list of places.
function parseResults(elements, type) {
  return elements
    .map(el => {
      const lat = el.lat ?? el.center?.lat;
      const lng = el.lon ?? el.center?.lon;
      if (!lat || !lng) return null;

      return {
        id: `${type}_${el.id}`,
        type,
        name: el.tags?.name || (type === 'hospital' ? 'Hospital' : 'Police Station'),
        lat,
        lng,
        address: [
          el.tags?.['addr:street'],
          el.tags?.['addr:city'],
        ].filter(Boolean).join(', ') || null,
        phone: el.tags?.phone || el.tags?.['contact:phone'] || null,
      };
    })
    .filter(Boolean);
}

// GET /api/overpass/nearby?lat=xx&lng=yy
// Returns nearby hospitals and police stations.
router.get('/nearby', requireAuth, async (req, res) => {
  const { lat, lng } = req.query;

  if (!lat || !lng) {
    return res.status(400).json({ message: 'lat and lng query params are required' });
  }

  const latF = parseFloat(lat);
  const lngF = parseFloat(lng);

  if (isNaN(latF) || isNaN(lngF)) {
    return res.status(400).json({ message: 'lat and lng must be valid numbers' });
  }

  try {
    // Run both queries in parallel
    const [hospitalResp, policeResp] = await Promise.allSettled([
      axios.post(
        OVERPASS_URL,
        `data=${encodeURIComponent(buildQuery(latF, lngF, 'hospital', SEARCH_RADIUS_M))}`,
        { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, timeout: 15000 }
      ),
      axios.post(
        OVERPASS_URL,
        `data=${encodeURIComponent(buildQuery(latF, lngF, 'police', SEARCH_RADIUS_M))}`,
        { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, timeout: 15000 }
      ),
    ]);

    const hospitals = hospitalResp.status === 'fulfilled'
      ? parseResults(hospitalResp.value.data.elements || [], 'hospital')
      : [];

    const police = policeResp.status === 'fulfilled'
      ? parseResults(policeResp.value.data.elements || [], 'police')
      : [];

    res.json({
      hospitals: hospitals.slice(0, 10),
      policeStations: police.slice(0, 10),
    });
  } catch (error) {
    console.error('[OVERPASS] error:', error.message);
    res.status(500).json({ message: 'Failed to fetch nearby services' });
  }
});

module.exports = router;
