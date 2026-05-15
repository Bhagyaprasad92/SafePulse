const admin = require('firebase-admin');
const twilio = require('twilio');
const path = require('path');

// Twilio SMS
const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken  = process.env.TWILIO_AUTH_TOKEN;
const twilioPhone = process.env.TWILIO_PHONE_NUMBER;

const twilioClient =
  accountSid && accountSid.startsWith('AC') && authToken
    ? twilio(accountSid, authToken)
    : null;

async function sendSMS(to, body) {
  if (!twilioClient || !twilioPhone) {
    console.warn(`[SMS] Twilio not configured. Would send to ${to}: ${body}`);
    return { success: false, reason: 'not_configured' };
  }
  try {
    const msg = await twilioClient.messages.create({ body, from: twilioPhone, to });
    console.log(`[SMS] Sent to ${to}: SID ${msg.sid}`);
    return { success: true, sid: msg.sid };
  } catch (err) {
    console.error(`[SMS] Failed to ${to}:`, err.message);
    return { success: false, error: err.message };
  }
}

// Firebase Admin + FCM
let firebaseApp = null;

function getFirebaseApp() {
  if (firebaseApp) return firebaseApp;
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!serviceAccountPath) {
    console.warn('[FCM] FIREBASE_SERVICE_ACCOUNT_PATH not set');
    return null;
  }
  try {
    const serviceAccount = require(path.resolve(serviceAccountPath));
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('[FCM] Firebase Admin initialised');
  } catch (err) {
    console.error('[FCM] Failed to initialise Firebase Admin:', err.message);
    firebaseApp = null;
  }
  return firebaseApp;
}

/**
 * Send a push notification to a list of FCM tokens.
 * Uses multicast (max 500 tokens per call).
 */
async function sendPushNotification(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) return { success: true, skipped: 'no_tokens' };

  const app = getFirebaseApp();
  if (!app) {
    console.warn('[FCM] Not configured. Would push to', tokens.length, 'devices:', title);
    return { success: false, reason: 'not_configured' };
  }

  const CHUNK = 500;
  const results = [];
  for (let i = 0; i < tokens.length; i += CHUNK) {
    const chunk = tokens.slice(i, i + CHUNK);
    const message = {
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      tokens: chunk,
    };
    try {
      const resp = await admin.messaging(app).sendEachForMulticast(message);
      console.log(`[FCM] Sent ${resp.successCount}/${chunk.length}`);
      results.push(resp);
    } catch (err) {
      console.error('[FCM] Multicast error:', err.message);
    }
  }
  return { success: true, results };
}

/**
 * Send to a single device token.
 */
async function sendToUser(token, title, body, data = {}) {
  if (!token) return;
  return sendPushNotification([token], title, body, data);
}

/**
 * Broadcast to all circle member tokens.
 */
async function broadcastToCircle(tokens, title, body, data = {}) {
  return sendPushNotification(tokens, title, body, data);
}

module.exports = { sendSMS, sendPushNotification, sendToUser, broadcastToCircle };
