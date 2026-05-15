const mongoose = require('mongoose');

const riskIncidentSchema = new mongoose.Schema({
  label: { type: String, required: true },
  category: {
    type: String,
    enum: ['ACCIDENT', 'CRIME', 'LOW_LIGHT', 'ROAD_HAZARD', 'COMMUNITY_REPORT'],
    default: 'COMMUNITY_REPORT',
  },
  severity: { type: Number, min: 0, max: 100, required: true },
  radiusM: { type: Number, min: 50, max: 5000, default: 500 },
  source: { type: String, default: 'community' },
  active: { type: Boolean, default: true },
  locationPoint: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], required: true },
  },
  expiresAt: Date,
}, { timestamps: true });

riskIncidentSchema.index({ locationPoint: '2dsphere' });
riskIncidentSchema.index({ active: 1, expiresAt: 1 });

module.exports = mongoose.model('RiskIncident', riskIncidentSchema);
