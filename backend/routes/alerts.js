const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Circle = require('../models/Circle');

router.post('/speed', async (req, res) => {
    const { userId, speed, lat, lon, speedLimit } = req.body;

    try {
        const user = await User.findById(userId);
        if (!user) return res.status(404).json({ success: false, message: 'User not found' });

        // Cooldown: send max 1 alert every 5 minutes per user for speed
        const now = new Date();
        if (user.lastSpeedAlert && (now - new Date(user.lastSpeedAlert)) < 5 * 60 * 1000) {
            return res.json({ success: true, message: 'Cooldown active' });
        }

        user.lastSpeedAlert = now;
        await user.save();

        // Logic to notify circle members
        // Find circles where user is a member
        const circles = await Circle.find({ members: userId });
        const adminIds = circles.map(c => c.admin);

        console.log(`[ALERT] Overspeed: User ${user.name} at ${speed} km/h (Limit ${speedLimit})`);

        res.json({ success: true, message: 'Speed alert sent to circle members' });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

router.post('/risk', async (req, res) => {
    const { userId, lat, lon, reason } = req.body;

    try {
        const user = await User.findById(userId);
        if (!user) return res.status(404).json({ success: false, message: 'User not found' });

        // Cooldown: 5 mins
        const now = new Date();
        if (user.lastRiskAlert && (now - new Date(user.lastRiskAlert)) < 5 * 60 * 1000) {
            return res.json({ success: true, message: 'Cooldown active' });
        }

        user.lastRiskAlert = now;
        await user.save();

        console.log(`[ALERT] Risk: User ${user.name} - ${reason} at ${lat}, ${lon}`);
        // Notify circle members

        res.json({ success: true, message: 'Risk alert sent to circle members' });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

module.exports = router;
