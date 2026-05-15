const safetyEngine = require('./safety_engine');
const { verifyToken } = require('../middleware/auth');

let WebSocketServer;
try {
  ({ WebSocketServer } = require('ws'));
} catch (error) {
  WebSocketServer = null;
}

function safeJsonParse(value) {
  try {
    return JSON.parse(value);
  } catch (error) {
    return null;
  }
}

function sendJson(socket, payload) {
  if (socket.readyState === socket.OPEN) {
    socket.send(JSON.stringify(payload));
  }
}

function createNoopHub() {
  return {
    isEnabled: false,
    clientCount: () => 0,
    broadcastToUser: () => false,
    broadcastToUsers: () => 0,
    broadcastSafetyEvent: () => 0,
  };
}

function extractToken(request) {
  const url = new URL(request.url, 'http://localhost');
  const queryToken = url.searchParams.get('token');
  if (queryToken) return queryToken;

  const protocol = request.headers['sec-websocket-protocol'];
  if (!protocol) return null;

  return protocol
    .split(',')
    .map(part => part.trim())
    .find(part => part.startsWith('Bearer '))
    ?.slice(7) || null;
}

function resolveUserId(request) {
  const token = extractToken(request);
  if (!token) return null;

  try {
    return verifyToken(token).userId;
  } catch (error) {
    return null;
  }
}

function createRealtimeHub(server) {
  if (!WebSocketServer) {
    console.warn('[REALTIME] ws dependency is unavailable; WebSocket hub disabled');
    return createNoopHub();
  }

  const clientsByUserId = new Map();
  const wss = new WebSocketServer({ server, path: '/ws/tracking' });

  function register(userId, socket) {
    if (!clientsByUserId.has(userId)) clientsByUserId.set(userId, new Set());
    clientsByUserId.get(userId).add(socket);
  }

  function unregister(userId, socket) {
    const sockets = clientsByUserId.get(userId);
    if (!sockets) return;
    sockets.delete(socket);
    if (sockets.size === 0) clientsByUserId.delete(userId);
  }

  function broadcastToUser(userId, payload) {
    const sockets = clientsByUserId.get(String(userId));
    if (!sockets) return false;

    for (const socket of sockets) {
      sendJson(socket, payload);
    }
    return true;
  }

  function broadcastToUsers(userIds, payload) {
    return [...new Set((userIds || []).map(String))]
      .reduce((sent, userId) => sent + (broadcastToUser(userId, payload) ? 1 : 0), 0);
  }

  function broadcastSafetyEvent(event) {
    const recipients = event.userIds || event.circleMemberIds || [];
    return broadcastToUsers(recipients, {
      type: event.type || 'safety:event',
      data: event.data || event,
      sentAt: new Date().toISOString(),
    });
  }

  function handleTrackingMessage(userId, socket, message) {
    const speed = Number(message.speed || 0);
    const isPhoneOn = Boolean(message.isPhoneOn);
    const result = safetyEngine.evaluateSafety(userId, speed, isPhoneOn);

    const response = {
      type: 'tracking:evaluated',
      data: {
        userId,
        status: result.status,
        message: result.message || 'Tracking active',
        location: message.location || null,
      },
      sentAt: new Date().toISOString(),
    };

    sendJson(socket, response);

    if (result.circleNotified && Array.isArray(message.circleMemberIds)) {
      broadcastToUsers(message.circleMemberIds, {
        type: 'circle:safety-alert',
        data: response.data,
        sentAt: response.sentAt,
      });
    }
  }

  wss.on('connection', (socket, request) => {
    const userId = resolveUserId(request);
    if (!userId) {
      sendJson(socket, { type: 'auth:error', message: 'Missing or invalid token' });
      socket.close(1008, 'Unauthorized');
      return;
    }

    register(String(userId), socket);
    sendJson(socket, { type: 'connection:ready', userId, sentAt: new Date().toISOString() });

    socket.on('message', raw => {
      const message = safeJsonParse(raw);
      if (!message || typeof message.type !== 'string') {
        sendJson(socket, { type: 'message:error', message: 'Invalid JSON message' });
        return;
      }

      if (message.type === 'tracking:update') {
        handleTrackingMessage(String(userId), socket, message);
        return;
      }

      if (message.type === 'sos:started') {
        broadcastSafetyEvent({
          type: 'circle:sos-alert',
          userIds: message.circleMemberIds || [],
          data: { userId, location: message.location, sosId: message.sosId },
        });
        return;
      }

      sendJson(socket, { type: 'message:error', message: `Unsupported type: ${message.type}` });
    });

    socket.on('close', () => unregister(String(userId), socket));
  });

  return {
    isEnabled: true,
    clientCount: () => [...clientsByUserId.values()].reduce((count, sockets) => count + sockets.size, 0),
    broadcastToUser,
    broadcastToUsers,
    broadcastSafetyEvent,
  };
}

module.exports = { createRealtimeHub };
