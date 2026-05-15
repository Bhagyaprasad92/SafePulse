/**
 * Crime Data API Routes
 * Provides endpoints for crime data analysis and risk scoring
 */

const express = require('express');
const router = express.Router();
const { CrimeDataService } = require('../services/crime_data_service');

const crimeService = new CrimeDataService();

/**
 * GET /api/crime/risk
 * Get risk score for a specific location
 * Query params: lat, lon, radius (optional, default 1000m)
 */
router.get('/risk', async (req, res) => {
    try {
        const { lat, lon, radius } = req.query;

        if (!lat || !lon) {
            return res.status(400).json({
                success: false,
                error: 'Latitude and longitude are required'
            });
        }

        const latitude = parseFloat(lat);
        const longitude = parseFloat(lon);
        const searchRadius = radius ? parseInt(radius) : 1000;

        if (isNaN(latitude) || isNaN(longitude)) {
            return res.status(400).json({
                success: false,
                error: 'Invalid latitude or longitude'
            });
        }

        const riskData = await crimeService.getRiskAtLocation(
            latitude,
            longitude,
            searchRadius
        );

        res.json({
            success: true,
            location: { lat: latitude, lon: longitude },
            ...riskData
        });
    } catch (error) {
        console.error('Error in /api/crime/risk:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to calculate risk score',
            message: error.message
        });
    }
});

/**
 * POST /api/crime/analyze-route
 * Analyze risk along a route
 * Body: { points: [{ lat, lon }, ...] }
 */
router.post('/analyze-route', async (req, res) => {
    try {
        const { points } = req.body;

        if (!points || !Array.isArray(points) || points.length === 0) {
            return res.status(400).json({
                success: false,
                error: 'Route points array is required'
            });
        }

        // Validate points
        const validPoints = points.filter(p => {
            const lat = parseFloat(p.lat);
            const lon = parseFloat(p.lon);
            return !isNaN(lat) && !isNaN(lon);
        });

        if (validPoints.length === 0) {
            return res.status(400).json({
                success: false,
                error: 'No valid route points provided'
            });
        }

        const analysis = await crimeService.analyzeRoute(validPoints);

        res.json({
            success: true,
            routePointsAnalyzed: validPoints.length,
            ...analysis
        });
    } catch (error) {
        console.error('Error in /api/crime/analyze-route:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to analyze route',
            message: error.message
        });
    }
});

/**
 * GET /api/crime/hotspots
 * Get crime hotspots in a bounding box
 * Query params: south, west, north, east, minRisk (optional)
 */
router.get('/hotspots', async (req, res) => {
    try {
        const { south, west, north, east, minRisk } = req.query;

        if (!south || !west || !north || !east) {
            return res.status(400).json({
                success: false,
                error: 'Bounding box coordinates (south, west, north, east) are required'
            });
        }

        const bounds = {
            south: parseFloat(south),
            west: parseFloat(west),
            north: parseFloat(north),
            east: parseFloat(east)
        };

        const minRiskScore = minRisk ? parseInt(minRisk) : 50;

        const hotspots = await crimeService.getHotspotsInBounds(
            bounds.south,
            bounds.west,
            bounds.north,
            bounds.east,
            minRiskScore
        );

        res.json({
            success: true,
            count: hotspots.length,
            hotspots: hotspots
        });
    } catch (error) {
        console.error('Error in /api/crime/hotspots:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch hotspots',
            message: error.message
        });
    }
});

/**
 * GET /api/crime/stats
 * Get overall crime statistics (for admin/debugging)
 */
router.get('/stats', async (req, res) => {
    try {
        const { CrimeZone } = require('../services/crime_data_service');

        const totalZones = await CrimeZone.countDocuments();
        const avgRisk = await CrimeZone.aggregate([
            { $group: { _id: null, avgRiskScore: { $avg: '$riskScore' } } }
        ]);

        const highRiskZones = await CrimeZone.countDocuments({ riskScore: { $gte: 60 } });
        const moderateRiskZones = await CrimeZone.countDocuments({
            riskScore: { $gte: 40, $lt: 60 }
        });
        const lowRiskZones = await CrimeZone.countDocuments({ riskScore: { $lt: 40 } });

        res.json({
            success: true,
            statistics: {
                totalZones: totalZones,
                averageRiskScore: avgRisk[0]?.avgRiskScore || 0,
                distribution: {
                    highRisk: highRiskZones,
                    moderateRisk: moderateRiskZones,
                    lowRisk: lowRiskZones
                }
            }
        });
    } catch (error) {
        console.error('Error in /api/crime/stats:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch statistics',
            message: error.message
        });
    }
});

module.exports = router;