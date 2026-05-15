const { createRealtimeHub } = require('../services/realtime_hub');

jest.mock('ws', () => ({
  WebSocketServer: jest.fn().mockImplementation(() => ({
    on: jest.fn()
  }))
}), { virtual: true });

describe('Realtime Hub', () => {
  it('creates a websocket hub for tracking updates', () => {
    const hub = createRealtimeHub({});

    expect(hub.isEnabled).toBe(true);
    expect(hub.clientCount()).toBe(0);
  });
});
