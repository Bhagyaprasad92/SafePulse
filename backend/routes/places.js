const express = require('express');
const router = express.Router();
const axios = require('axios');


// Returns India-focused location suggestions using Nominatim.
router.get('/search', async (req, res) => {
  const { q } = req.query;
  if (!q || q.trim().length < 3) {
    return res.status(400).json({ error: 'Search query must be at least 3 characters' });
  }

  try {
    const url = 'https://nominatim.openstreetmap.org/search';
    const params = {
      q: q,
      format: 'json',
      addressdetails: 1,
      limit: 8,
      // countrycodes: 'in',
      // viewbox: '68.176645,37.090240,97.402561,6.554607',
      // bounded: 1 
    };

    console.log(`[PLACES] Searching Nominatim for: ${q}`);
    const response = await axios.get(url, {
      params,
      timeout: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' 
      }
    });

    console.log(`[PLACES] Nominatim returned ${response.data.length} results`);

    const results = response.data.map(item => ({
      displayName: item.display_name,
      lat: parseFloat(item.lat),
      lng: parseFloat(item.lon),
      address: item.address
    }));

    console.log(`[PLACES] Sending ${results.length} results to client`);
    res.json(results);
  } catch (error) {
    console.error('[PLACES] Search error:', error.message);
    if (error.response) {
      console.error('[PLACES] Response data:', error.response.data);
      console.error('[PLACES] Response status:', error.response.status);
    }
    res.status(500).json({ error: 'Failed to fetch location suggestions' });
  }
});

module.exports = router;
