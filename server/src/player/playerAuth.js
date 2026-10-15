const { randomBytes } = require('node:crypto');
const { AuthService } = require('../auth');

const SESSION_TTL_MS = 30 * 60 * 1000;
const MAX_SESSIONS = 10000;

class PlayerAuth {
  constructor(apiTokens, { now = Date.now, sessionTtlMs = SESSION_TTL_MS } = {}) {
    this.auth = new AuthService({ apiTokens, publicPaths: new Set() });
    this.sessions = new Map();
    this.now = now;
    this.sessionTtlMs = sessionTtlMs;
  }

  hasBearer(request) {
    return this.auth.isAuthorized(request, '', new URLSearchParams());
  }

  authorize(request, url) {
    if (url.pathname === '/health' || url.pathname === '/favicon.ico') return true;
    if (url.pathname === '/session') return this.hasBearer(request);
    if (this.hasBearer(request)) return true;
    const id = url.searchParams.get('session');
    const expiresAt = this.sessions.get(id);
    if (!expiresAt) return false;
    if (expiresAt <= this.now()) {
      this.sessions.delete(id);
      return false;
    }
    this.sessions.set(id, this.now() + this.sessionTtlMs);
    return true;
  }

  createSession() {
    const now = this.now();
    for (const [id, expiresAt] of this.sessions) {
      if (expiresAt <= now) this.sessions.delete(id);
    }

    if (this.sessions.size >= MAX_SESSIONS) {
      const error = new Error('Playback session capacity reached');
      error.statusCode = 503;
      throw error;
    }
    const id = randomBytes(32).toString('hex');
    this.sessions.set(id, now + this.sessionTtlMs);
    return id;
  }

  pageSession(url) {
    const id = url.searchParams.get('session');
    if (this.sessions.get(id) > this.now()) return id;
    return this.auth.enabled ? this.createSession() : null;
  }
}

module.exports = { PlayerAuth };
