const mongoose = require('mongoose');

const sosSchema = new mongoose.Schema({
  victimId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  location: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    address: String
  },
  status: { type: String, enum: ['ACTIVE', 'CANCELLED', 'RESOLVED'], default: 'ACTIVE' },
  contactsNotified: [{
    name: String,
    phone: String,
    status: { type: String, default: 'SENT' }
  }],
  nearbyUsersNotified: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  responders: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    status: { type: String, enum: ['RESPONDED', 'ARRIVED', 'COMPLETED'], default: 'RESPONDED' },
    timestamp: { type: Date, default: Date.now }
  }],
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('SOS', sosSchema);
