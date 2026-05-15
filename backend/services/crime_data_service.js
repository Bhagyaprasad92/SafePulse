/**
 * Crime Data Service
 * Processes FIR (First Information Report) crime data and provides APIs for risk zone analysis
 * 
 * Features:
 * - Parses large CSV file efficiently using streaming
 * - Calculates crime density using geospatial indexing
 * - Caches processed data in MongoDB
 * - Provides API for real-time risk scoring
 */

const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');
const mongoose = require('mongoose');

// Crime Zone Schema
const crimeZoneSchema = new mongoose.Schema({
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: [Number] // [longitude, latitude]
  },
  district: String,
  unit: String,
  crimeData: {
    totalCrimes: { type: Number, default: 0 },
    heinousCrimes: { type: Number, default: 0 },
    accidents: { type: Number, default: 0 },
    violentCrimes: { type: Number, default: 0 },
    propertyCrimes: { type: Number, default: 0 },
    byType: { type: Map, of: Number }
  },
  riskScore: { type: Number, min: 0, max: 100 },
  lastUpdated: { type: Date, default: Date.now }
}, {
  collection: 'crime_zones'
});

// Create geospatial index for efficient location queries
crimeZoneSchema.index({ location: '2dsphere' });
crimeZoneSchema.index({ district: 1, unit: 1 });

const CrimeZone = mongoose.model('CrimeZone', crimeZoneSchema);

class CrimeDataService {
  constructor() {
    this.GRID_SIZE = 0.01; // ~1km grid cells
    this.zoneCache = new Map();
  }

  /**
   * Parse FIR CSV and aggregate crime data by geographic zones
   * @param {string} csvFilePath - Path to FIR_Details_Data.csv
   */
  async processFIRData(csvFilePath) {
    console.log('Starting FIR data processing...');
    const startTime = Date.now();
    
    const zoneMap = new Map();
    let processedCount = 0;
    let skippedCount = 0;

    return new Promise((resolve, reject) => {
      fs.createReadStream(csvFilePath)
        .pipe(csv())
        .on('data', (row) => {
          try {
            const lat = parseFloat(row.Latitude);
            const lon = parseFloat(row.Longitude);
            
            // Skip rows without valid coordinates
            if (!lat || !lon || isNaN(lat) || isNaN(lon)) {
              skippedCount++;
              return;
            }

            // Create grid cell key (rounds to nearest grid)
            const gridLat = Math.round(lat / this.GRID_SIZE) * this.GRID_SIZE;
            const gridLon = Math.round(lon / this.GRID_SIZE) * this.GRID_SIZE;
            const zoneKey = `${gridLat.toFixed(4)},${gridLon.toFixed(4)}`;

            // Initialize zone if not exists
            if (!zoneMap.has(zoneKey)) {
              zoneMap.set(zoneKey, {
                lat: gridLat,
                lon: gridLon,
                district: row.District_Name || 'Unknown',
                unit: row.UnitName || 'Unknown',
                crimes: [],
                totalCrimes: 0,
                heinousCrimes: 0,
                accidents: 0,
                violentCrimes: 0,
                propertyCrimes: 0,
                crimeTypes: new Map()
              });
            }

            const zone = zoneMap.get(zoneKey);
            
            // Categorize crime
            const firType = (row['FIR Type'] || '').toLowerCase();
            const crimeGroup = (row.CrimeGroup_Name || '').toLowerCase();
            const crimeHead = (row.CrimeHead_Name || '').toLowerCase();

            zone.totalCrimes++;
            
            // Count heinous crimes
            if (firType.includes('heinous')) {
              zone.heinousCrimes++;
            }

            // Count accidents
            if (crimeGroup.includes('accident') || crimeGroup.includes('motor vehicle')) {
              zone.accidents++;
            }

            // Count violent crimes
            if (crimeGroup.includes('murder') || 
                crimeGroup.includes('rape') || 
                crimeGroup.includes('assault') ||
                crimeGroup.includes('kidnapping') ||
                crimeHead.includes('murder') ||
                crimeHead.includes('rape')) {
              zone.violentCrimes++;
            }

            // Count property crimes
            if (crimeGroup.includes('theft') || 
                crimeGroup.includes('burglary') || 
                crimeGroup.includes('robbery')) {
              zone.propertyCrimes++;
            }

            // Track crime types
            if (crimeGroup) {
              zone.crimeTypes.set(
                crimeGroup, 
                (zone.crimeTypes.get(crimeGroup) || 0) + 1
              );
            }

            processedCount++;
            
            if (processedCount % 10000 === 0) {
              console.log(`Processed ${processedCount} records...`);
            }
          } catch (error) {
            console.error('Error processing row:', error);
            skippedCount++;
          }
        })
        .on('end', async () => {
          console.log(`\nProcessing complete!`);
          console.log(`- Total records processed: ${processedCount}`);
          console.log(`- Records skipped: ${skippedCount}`);
          console.log(`- Unique zones created: ${zoneMap.size}`);
          console.log(`- Time taken: ${(Date.now() - startTime) / 1000}s`);

          // Save to MongoDB
          await this.saveZonesToDatabase(zoneMap);
          resolve({ processedCount, skippedCount, zoneCount: zoneMap.size });
        })
        .on('error', reject);
    });
  }

  /**
   * Save processed zones to MongoDB
   */
  async saveZonesToDatabase(zoneMap) {
    console.log('\nSaving zones to database...');
    
    // Clear existing data
    await CrimeZone.deleteMany({});
    
    const bulkOps = [];
    
    for (const [key, zone] of zoneMap) {
      // Calculate risk score (0-100)
      const riskScore = this.calculateRiskScore(zone);
      
      const crimeTypeObj = {};
      zone.crimeTypes.forEach((count, type) => {
        crimeTypeObj[type] = count;
      });

      bulkOps.push({
        insertOne: {
          document: {
            location: {
              type: 'Point',
              coordinates: [zone.lon, zone.lat] // GeoJSON uses [lon, lat]
            },
            district: zone.district,
            unit: zone.unit,
            crimeData: {
              totalCrimes: zone.totalCrimes,
              heinousCrimes: zone.heinousCrimes,
              accidents: zone.accidents,
              violentCrimes: zone.violentCrimes,
              propertyCrimes: zone.propertyCrimes,
              byType: crimeTypeObj
            },
            riskScore: riskScore
          }
        }
      });

      // Batch insert every 1000 documents
      if (bulkOps.length >= 1000) {
        await CrimeZone.bulkWrite(bulkOps);
        console.log(`Saved ${bulkOps.length} zones...`);
        bulkOps.length = 0;
      }
    }

    // Insert remaining
    if (bulkOps.length > 0) {
      await CrimeZone.bulkWrite(bulkOps);
    }

    console.log('Database save complete!');
  }

  /**
   * Calculate risk score based on crime statistics
   * Returns value from 0 (safe) to 100 (very dangerous)
   */
  calculateRiskScore(zone) {
    // Weighted scoring system
    const weights = {
      heinous: 10,
      violent: 8,
      accident: 5,
      property: 3,
      other: 1
    };

    let score = 0;
    score += zone.heinousCrimes * weights.heinous;
    score += zone.violentCrimes * weights.violent;
    score += zone.accidents * weights.accident;
    score += zone.propertyCrimes * weights.property;
    score += (zone.totalCrimes - zone.heinousCrimes - zone.violentCrimes - 
              zone.accidents - zone.propertyCrimes) * weights.other;

    // Normalize to 0-100 scale using logarithmic scaling
    // This prevents extreme values while still differentiating risk levels
    const normalized = Math.min(100, (Math.log10(score + 1) / Math.log10(1000)) * 100);
    
    return Math.round(normalized);
  }

  /**
   * Get risk score for a specific location
   * @param {number} lat - Latitude
   * @param {number} lon - Longitude
   * @param {number} radiusMeters - Search radius in meters
   * @returns {Promise<Object>} Risk assessment data
   */
  async getRiskAtLocation(lat, lon, radiusMeters = 1000) {
    try {
      // Find nearby crime zones
      const zones = await CrimeZone.find({
        location: {
          $near: {
            $geometry: {
              type: 'Point',
              coordinates: [lon, lat]
            },
            $maxDistance: radiusMeters
          }
        }
      }).limit(10);

      if (zones.length === 0) {
        return {
          riskScore: 0,
          riskLevel: 'unknown',
          nearbyZones: 0,
          message: 'No crime data available for this area'
        };
      }

      // Calculate weighted average risk score based on distance
      let totalWeight = 0;
      let weightedScore = 0;

      zones.forEach(zone => {
        const distance = this.getDistance(
          lat, lon, 
          zone.location.coordinates[1], 
          zone.location.coordinates[0]
        );
        
        // Inverse distance weighting (closer zones have more influence)
        const weight = 1 / (distance + 1);
        weightedScore += zone.riskScore * weight;
        totalWeight += weight;
      });

      const avgRiskScore = Math.round(weightedScore / totalWeight);
      
      // Aggregate crime statistics
      const aggregateStats = {
        totalCrimes: 0,
        heinousCrimes: 0,
        accidents: 0,
        violentCrimes: 0
      };

      zones.forEach(z => {
        aggregateStats.totalCrimes += z.crimeData.totalCrimes;
        aggregateStats.heinousCrimes += z.crimeData.heinousCrimes;
        aggregateStats.accidents += z.crimeData.accidents;
        aggregateStats.violentCrimes += z.crimeData.violentCrimes;
      });

      return {
        riskScore: avgRiskScore,
        riskLevel: this.getRiskLevel(avgRiskScore),
        nearbyZones: zones.length,
        statistics: aggregateStats,
        zones: zones.map(z => ({
          location: z.location.coordinates,
          district: z.district,
          riskScore: z.riskScore,
          crimes: z.crimeData.totalCrimes
        }))
      };
    } catch (error) {
      console.error('Error getting risk at location:', error);
      throw error;
    }
  }

  /**
   * Get risk scores for multiple points along a route
   * @param {Array} routePoints - Array of {lat, lon} coordinates
   * @returns {Promise<Object>} Route risk analysis
   */
  async analyzeRoute(routePoints) {
    const riskScores = [];
    let totalRisk = 0;
    let maxRisk = 0;
    const highRiskSegments = [];

    for (let i = 0; i < routePoints.length; i++) {
      const point = routePoints[i];
      const risk = await this.getRiskAtLocation(point.lat, point.lon, 500);
      
      riskScores.push({
        index: i,
        lat: point.lat,
        lon: point.lon,
        riskScore: risk.riskScore,
        riskLevel: risk.riskLevel
      });

      totalRisk += risk.riskScore;
      maxRisk = Math.max(maxRisk, risk.riskScore);

      // Flag high-risk segments (score > 60)
      if (risk.riskScore > 60) {
        highRiskSegments.push({
          index: i,
          location: { lat: point.lat, lon: point.lon },
          riskScore: risk.riskScore,
          details: risk.statistics
        });
      }
    }

    const avgRisk = routePoints.length > 0 ? totalRisk / routePoints.length : 0;

    return {
      averageRisk: Math.round(avgRisk),
      maxRisk: maxRisk,
      overallLevel: this.getRiskLevel(avgRisk),
      pointAnalysis: riskScores,
      highRiskSegments: highRiskSegments,
      safetyScore: Math.max(0, 100 - avgRisk) // Inverse of risk
    };
  }

  /**
   * Get risk level label from score
   */
  getRiskLevel(score) {
    if (score < 20) return 'low';
    if (score < 40) return 'moderate';
    if (score < 60) return 'high';
    return 'very_high';
  }

  /**
   * Calculate distance between two points (Haversine formula)
   */
  getDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // Earth radius in meters
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  /**
   * Get crime hotspots in a bounding box
   */
  async getHotspotsInBounds(south, west, north, east, minRiskScore = 50) {
    const hotspots = await CrimeZone.find({
      location: {
        $geoWithin: {
          $box: [
            [west, south],
            [east, north]
          ]
        }
      },
      riskScore: { $gte: minRiskScore }
    }).sort({ riskScore: -1 }).limit(100);

    return hotspots.map(h => ({
      lat: h.location.coordinates[1],
      lon: h.location.coordinates[0],
      riskScore: h.riskScore,
      riskLevel: this.getRiskLevel(h.riskScore),
      district: h.district,
      crimes: h.crimeData.totalCrimes
    }));
  }
}

module.exports = { CrimeDataService, CrimeZone };
