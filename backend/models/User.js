const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  phone: { type: String, unique: true, sparse: true },
  name: { type: String, required: true },
  email: { type: String, unique: true, sparse: true },
  profilePic: { type: String },
  loginType: { type: String, enum: ['email', 'phone'], default: 'phone' },
  emergencyContacts: [{
    name: String,
    phone: String,
    relation: String
  }],
  circles: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Circle' }],
  location: {
    lat: Number,
    lng: Number,
    address: String
  },
  locationPoint: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] } // [lng, lat]
  },
  batteryLevel: { type: String, default: "100%" },
  isDriving: { type: Boolean, default: false },
  currentSpeed: { type: Number, default: 0 },
  fcmToken: { type: String }, // For push notifications
  lastSeen: { type: Date, default: Date.now },
  createdAt: { type: Date, default: Date.now },
  otp: { type: String },
  otpExpiry: { type: Date },
  lastSpeedAlert: { type: Date },
  lastRiskAlert: { type: Date },

  // ===== ADDED: For Circle Map real-time location =====
  lastLocation: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
    updatedAt: { type: Date, default: null }
  }
  // ====================================================
});

userSchema.index({ locationPoint: '2dsphere' });

module.exports = mongoose.model('User', userSchema);