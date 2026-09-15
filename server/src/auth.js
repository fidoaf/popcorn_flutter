// Owns everything about request authentication: extracting tokens, deciding
// whether a request is allowed, and building the token query suffix used when
// the server links back to its own proxy endpoints.
const { createLogger } = require('./logger');

const log = createLogger('auth');

class AuthService {
  constructor({ apiTokens, publicPaths }) {
    this.apiTokens = apiTokens;
    this.publicPaths = publicPaths;
    log.debug('auth configured', { enabled: apiTokens.size > 0, tokenCount: apiTokens.size });
  }

  get enabled() {
    return this.apiTokens.size > 0;
  }

  extractToken(req, searchParams) {
    const header = req.headers['authorization'] || '';
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (match) return match[1].trim();
    return searchParams.get('token') || searchParams.get('access_token') || null;
  }

  isAuthorized(req, pathname, searchParams) {
    if (this.publicPaths.has(pathname)) {
      log.debug('authorized: public path', { pathname });
      return true;
    }
    if (!this.enabled) {
      log.debug('authorized: auth disabled', { pathname });
      return true;
    }
    const token = this.extractToken(req, searchParams);
    const ok = token != null && this.apiTokens.has(token);
    log.debug('auth decision', { pathname, provided: token != null, authorized: ok });
    return ok;
  }

  tokenQuery(token) {
    return token ? '&token=' + encodeURIComponent(token) : '';
  }
}

module.exports = { AuthService };
