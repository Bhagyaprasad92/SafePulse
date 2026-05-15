describe('Auth Middleware Secret Handling', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('uses an isolated test secret during automated tests', () => {
    delete process.env.JWT_SECRET;
    process.env.NODE_ENV = 'test';

    const { signToken, verifyToken } = require('../middleware/auth');
    const token = signToken('user-1');

    expect(verifyToken(token).userId).toBe('user-1');
  });

  it('fails fast outside test when JWT_SECRET is missing', () => {
    delete process.env.JWT_SECRET;
    process.env.NODE_ENV = 'production';

    const { signToken } = require('../middleware/auth');

    expect(() => signToken('user-1')).toThrow('JWT_SECRET environment variable is required');
  });
});
