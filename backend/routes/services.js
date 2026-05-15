const express = require('express');
const router = express.Router();
const axios = require('axios');

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';

const INDIA_BOUNDS = {
    south: 6.554607,
    west: 68.176645,
    north: 37.090240,
    east: 97.402561,
};

function isInsideIndia(lat, lon) {
    return lat >= INDIA_BOUNDS.south && lat <= INDIA_BOUNDS.north &&
           lon >= INDIA_BOUNDS.west && lon <= INDIA_BOUNDS.east;
}

function clampBBoxToIndia(s, w, n, e) {
    return {
        s: Math.max(s, INDIA_BOUNDS.south),
        w: Math.max(w, INDIA_BOUNDS.west),
        n: Math.min(n, INDIA_BOUNDS.north),
        e: Math.min(e, INDIA_BOUNDS.east)
    };
}

// GET /api/services/nearby?lat=...&lon=...&radius=3000
router.get('/nearby', async (req, res) => {
    const { lat, lon, radius = 3000 } = req.query;
    const userLat = parseFloat(lat);
    const userLon = parseFloat(lon);

    if (isNaN(userLat) || isNaN(userLon)) {
        return res.status(400).json({ success: false, message: 'Invalid lat/lon' });
    }

    try {
        const query = `
            [out:json][timeout:25];
            (
              node["amenity"~"hospital|clinic|doctors|medical_centre"](around:${radius}, ${userLat}, ${userLon});
              way["amenity"~"hospital|clinic|doctors|medical_centre"](around:${radius}, ${userLat}, ${userLon});
              relation["amenity"~"hospital|clinic|doctors|medical_centre"](around:${radius}, ${userLat}, ${userLon});

              node["amenity"~"police|police_station"](around:${radius}, ${userLat}, ${userLon});
              way["amenity"~"police|police_station"](around:${radius}, ${userLat}, ${userLon});
              relation["amenity"~"police|police_station"](around:${radius}, ${userLat}, ${userLon});
            );
            out center tags;
        `;
        
        const response = await axios.get(OVERPASS_URL, {
            params: { data: query },
            timeout: 25000,
            headers: { 'User-Agent': 'SafePulseApp/1.0 (contact: support@safepulse.app)' }
        });

        const elements = response.data.elements || [];
        const seen = new Set();
        
        const hospitals = [];
        const police = [];

        elements.forEach(el => {
            const lat = el.lat ?? el.center?.lat;
            const lon = el.lon ?? el.center?.lon;
            if (!lat || !lon) return;

            const tags = el.tags || {};
            const amenity = (tags.amenity || "").toLowerCase();
            const healthcare = (tags.healthcare || "").toLowerCase();
            const policeTag = (tags.police || "").toLowerCase();
            
            let type = 'unknown';
            let name = tags.name || tags.operator;

            if (amenity === 'police' || policeTag === 'station' || amenity === 'police_station') {
                type = 'police';
                name = name || "Police Station";
            } else if (
                ['hospital', 'clinic', 'medical_centre', 'doctors'].includes(amenity) || 
                ['hospital', 'clinic'].includes(healthcare)
            ) {
                type = 'hospital';
                name = name || (amenity === 'hospital' ? "Hospital" : "Medical Facility");
            }

            if (type === 'unknown') return;

            // Deduplicate
            const key = `${el.type}/${el.id}`;
            if (!seen.has(key)) {
                seen.add(key);
                const serviceObj = {
                    id: key,
                    name: name,
                    type: type,
                    lat: lat,
                    lon: lon,
                    distanceMeters: calculateDistance(userLat, userLon, lat, lon)
                };

                if (type === 'hospital') hospitals.push(serviceObj);
                else police.push(serviceObj);
            }
        });

        // Sort by distance
        hospitals.sort((a, b) => a.distanceMeters - b.distanceMeters);
        police.sort((a, b) => a.distanceMeters - b.distanceMeters);

        const counts = {
            hospitals: hospitals.length,
            police: police.length
        };

        console.log(`[SERVICES] Found ${hospitals.length} hospitals and ${police.length} police stations within ${radius}m`);

        res.json({ 
            success: true, 
            counts, 
            services: {
                hospitals,
                police
            }
        });
    } catch (error) {
        console.error('[SERVICES] Error fetching nearby:', error.message);
        res.status(500).json({ success: false, message: 'Failed to fetch nearby services' });
    }
});

// GET /api/services/bbox?south=...&west=...&north=...&east=...&type=...
router.get('/bbox', async (req, res) => {
    const { south, west, north, east, type } = req.query;

    if (!south || !west || !north || !east) {
        return res.status(400).json({ success: false, message: 'Missing bbox coordinates' });
    }

    const s_raw = parseFloat(south);
    const w_raw = parseFloat(west);
    const n_raw = parseFloat(north);
    const e_raw = parseFloat(east);

    const { s, w, n, e } = { s: s_raw, w: w_raw, n: n_raw, e: e_raw };

    let query = '';
    if (type === 'hospital' || type === 'all') {
        query += `
            node["amenity"~"hospital|clinic|doctors|pharmacy"](${s},${w},${n},${e});
            way["amenity"~"hospital|clinic|doctors|pharmacy"](${s},${w},${n},${e});
            relation["amenity"~"hospital|clinic|doctors|pharmacy"](${s},${w},${n},${e});
            node["healthcare"~"hospital|clinic|doctor|centre|laboratory|pharmacy"](${s},${w},${n},${e});
            way["healthcare"~"hospital|clinic|doctor|centre|laboratory|pharmacy"](${s},${w},${n},${e});
            relation["healthcare"~"hospital|clinic|doctor|centre|laboratory|pharmacy"](${s},${w},${n},${e});
        `;
    }
    if (type === 'police' || type === 'all') {
        query += `
            node["amenity"="police"](${s},${w},${n},${e});
            way["amenity"="police"](${s},${w},${n},${e});
            relation["amenity"="police"](${s},${w},${n},${e});
            node["police"~"station|post|checkpoint"](${s},${w},${n},${e});
            way["police"~"station|post|checkpoint"](${s},${w},${n},${e});
            relation["police"~"station|post|checkpoint"](${s},${w},${n},${e});
        `;
    }

    const overpassQuery = `
        [out:json][timeout:30];
        (
            ${query}
        );
        out center tags;
    `;

    try {
        const response = await axios.get(OVERPASS_URL, {
            params: { data: overpassQuery },
            timeout: 25000,
            headers: { 'User-Agent': 'SafePulseApp/1.0 (contact: support@safepulse.app)' }
        });

        const elements = response.data.elements || [];
        const seen = new Set();
        const services = [];

        elements.forEach(el => {
            const lat = el.lat ?? el.center?.lat;
            const lon = el.lon ?? el.center?.lon;
            if (!lat || !lon) return;

            const tags = el.tags || {};
            const name = tags.name || tags.operator || (tags.amenity === 'police' ? "Police Station" : "Medical Facility");
            
            let classifiedType = 'unknown';
            const amenity = (tags.amenity || "").toLowerCase();
            const healthcare = (tags.healthcare || "").toLowerCase();
            const policeTag = (tags.police || "").toLowerCase();

            if (amenity === 'police' || policeTag || tags['amenity'] === 'police') {
                classifiedType = 'police';
            } else if (['hospital', 'clinic', 'doctors', 'pharmacy', 'medical_centre'].includes(amenity) || healthcare || tags['amenity'] === 'hospital') {
                classifiedType = 'hospital';
            }

            if (classifiedType === 'unknown') return;

            const key = `${el.id}_${lat.toFixed(4)}_${lon.toFixed(4)}`;
            if (!seen.has(key)) {
                seen.add(key);
                services.push({
                    id: `${el.type}/${el.id}`,
                    name: name,
                    type: classifiedType,
                    subType: amenity || healthcare || policeTag || 'general',
                    lat: lat,
                    lon: lon,
                    tags: tags
                });
            }
        });

        res.json({ 
            success: true, 
            type: type,
            count: services.length, 
            services: services 
        });
    } catch (error) {
        console.error('[SERVICES] BBOX Error:', error.message);
        res.status(500).json({ success: false, message: 'BBOX query failed' });
    }
});

function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3;
    const phi1 = lat1 * Math.PI / 180;
    const phi2 = lat2 * Math.PI / 180;
    const deltaPhi = (lat2 - lat1) * Math.PI / 180;
    const deltaLambda = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
              Math.cos(phi1) * Math.cos(phi2) *
              Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return Math.round(R * c);
}

module.exports = router;
