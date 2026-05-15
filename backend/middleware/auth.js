const jwt = require('jsonwebtoken');

function getJwtSecret() {
  if (process.env.JWT_SECRET) return process.env.JWT_SECRET;
  if (process.env.NODE_ENV === 'test') return 'safepulse_test_secret';

  throw new Error('JWT_SECRET environment variable is required');
}

// verifies Bearer token in Authorization header.
// Attaches req.userId for use in protected routes.
function requireAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Missing or invalid Authorization header' });
  }
  const token = authHeader.slice(7);
  try {
    const payload = jwt.verify(token, getJwtSecret());
    req.userId = payload.userId;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Token expired or invalid' });
  }
}

function verifyToken(token) {
  return jwt.verify(token, getJwtSecret());
}

// Generate a JWT for a user. Call after OTP verification.
function signToken(userId) {
  return jwt.sign({ userId }, getJwtSecret(), { expiresIn: '30d' });
}

module.exports = { requireAuth, signToken, verifyToken };
