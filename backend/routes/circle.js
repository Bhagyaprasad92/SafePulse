const express = require('express');
const router = express.Router();
const Circle = require('../models/Circle');
const User = require('../models/User');
const { requireAuth } = require('../middleware/auth');

// Create Circle
router.post('/create', requireAuth, async (req, res) => {
  const { name } = req.body;
  const userId = req.userId; // Extracted from token
  console.log(`[CIRCLE] Creating circle: ${name} for user: ${userId}`);
  
  if (!name) return res.status(400).json({ success: false, message: 'Circle name is required' });

  const inviteCode = Math.random().toString(36).substring(2, 7).toUpperCase();
  try {
    const circle = new Circle({
      name,
      owner: userId,
      members: [userId],
      inviteCode
    });
    await circle.save();
    
    // Add circle to user
    await User.findByIdAndUpdate(userId, { $push: { circles: circle._id } });
    
    console.log(`[CIRCLE] Circle created successfully: ${circle._id} code: ${inviteCode}`);
    res.json({ success: true, circle });
  } catch (error) {
    console.error(`[CIRCLE] Create Error: ${error.message}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Join Circle
router.post('/join', requireAuth, async (req, res) => {
  const { inviteCode } = req.body;
  const userId = req.userId;
  try {
    const circle = await Circle.findOne({ inviteCode });
    if (!circle) return res.status(404).json({ success: false, message: 'Invalid invite code' });
    
    // Check if user is already a member using a more robust comparison
    const isMember = circle.members.some(m => m.toString() === userId);
    
    if (!isMember) {
      circle.members.push(userId);
      await circle.save();
    }
    
    // Always ensure the circle is in the user's list (idempotent sync)
    await User.findByIdAndUpdate(userId, { $addToSet: { circles: circle._id } });
    
    res.json({ success: true, circle });
  } catch (error) {
    console.error(`[CIRCLE] Join Error: ${error.message}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get User Circles (My Circles)
router.get('/my', requireAuth, async (req, res) => {
  try {
    const user = await User.findById(req.userId).populate({
      path: 'circles',
      populate: { 
        path: 'members', 
        select: 'name phone batteryLevel isDriving currentSpeed location lastSeen' 
      }
    });
    res.json({ success: true, circles: user.circles || [] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /circle/:circleId/members-location — returns all members with their live location
router.get('/:circleId/members-location', requireAuth, async (req, res) => {
  try {
    const circle = await Circle.findById(req.params.circleId).populate({
      path: 'members',
      select: 'name phone profilePic batteryLevel isDriving currentSpeed location lastSeen'
    });

    if (!circle) {
      return res.status(404).json({ success: false, message: 'Circle not found' });
    }

    // Only allow members of this circle to fetch locations
    const isMember = circle.members.some(m => m._id.toString() === req.userId);
    if (!isMember) {
      return res.status(403).json({ success: false, message: 'Not a member of this circle' });
    }

    const members = circle.members.map(m => ({
      _id: m._id,
      name: m.name,
      phone: m.phone,
      profilePic: m.profilePic,
      batteryLevel: m.batteryLevel,
      isDriving: m.isDriving,
      currentSpeed: m.currentSpeed,
      lastSeen: m.lastSeen,
      location: m.location,          // { lat, lng, address }
      lastLocation: m.location,      // alias so CircleMapPage works with both field names
    }));

    res.json({ success: true, members });
  } catch (error) {
    console.error(`[CIRCLE] members-location error: ${error.message}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

// PUT /circle/update-location — update calling user's location in DB
router.put('/update-location', requireAuth, async (req, res) => {
  try {
    const { lat, lng, address } = req.body;
    if (lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, message: 'lat and lng required' });
    }

    await User.findByIdAndUpdate(req.userId, {
      location: { lat, lng, address: address || '' },
      locationPoint: { type: 'Point', coordinates: [lng, lat] },
      lastSeen: new Date(),
    });

    res.json({ success: true });
  } catch (error) {
    console.error(`[CIRCLE] update-location error: ${error.message}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /circle/:circleId/request-delete — vote to delete circle
router.post('/:circleId/request-delete', requireAuth, async (req, res) => {
  try {
    const circle = await Circle.findById(req.params.circleId);
    if (!circle) return res.status(404).json({ success: false, message: 'Circle not found' });

    // Check if user is member
    if (!circle.members.some(m => m.toString() === req.userId)) {
      return res.status(403).json({ success: false, message: 'Not a member' });
    }

    // Add user to deletion requests (idempotent)
    const userIdStr = req.userId.toString();
    const alreadyVoted = circle.deletionRequests.some(r => r.toString() === userIdStr);
    
    if (!alreadyVoted) {
      circle.deletionRequests.push(req.userId);
      await circle.save();
    }

    // Check consensus
    if (circle.deletionRequests.length >= circle.members.length) {
      // DELETE CIRCLE
      await Circle.findByIdAndDelete(circle._id);
      // Remove from all users
      await User.updateMany(
        { circles: circle._id },
        { $pull: { circles: circle._id } }
      );
      return res.json({ success: true, deleted: true, message: 'Circle deleted by consensus' });
    }

    res.json({ 
      success: true, 
      deleted: false, 
      votes: circle.deletionRequests.length, 
      totalNeeded: circle.members.length 
    });
  } catch (error) {
    console.error(`[CIRCLE] delete error: ${error.message}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;