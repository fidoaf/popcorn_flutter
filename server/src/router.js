const { sendJson } = require('./httpResponse');
const { createLogger } = require('./logger');

const log = createLogger('router');

// Maps request paths to controller methods and enforces auth before dispatch.
// Adding an endpoint means registering a route here — handlers don't know about
// routing or authorization concerns (Single Responsibility).
class Router {
  constructor({ auth }) {
    this.auth = auth;
    this.routes = new Map();
    this._seq = 0;
  }

  register(pathname, handler) {
    this.routes.set(pathname, handler);
    log.debug('route registered', { pathname });
    return this;
  }

  async handle(req, res) {
    const startedAt = Date.now();
    const reqId = `r${(++this._seq).toString(36)}-${startedAt.toString(36)}`;
    req.id = reqId;
    req.log = log.child(reqId);

    const remote = req.socket ? req.socket.remoteAddress : undefined;
    req.log.info('request received', {
      method: req.method,
      url: req.url,
      host: req.headers.host,
      remote,
      userAgent: req.headers['user-agent'],
      hasAuthHeader: Boolean(req.headers['authorization']),
    });

    res.on('finish', () => {
      req.log.info('request completed', {
        status: res.statusCode,
        durationMs: Date.now() - startedAt,
      });
    });
    res.on('close', () => {
      if (!res.writableEnded) {
        req.log.warn('connection closed before response finished', {
          durationMs: Date.now() - startedAt,
        });
      }
    });

    try {
      const url = new URL(req.url, `http://${req.headers.host}`);

      // CORS preflight requests carry no credentials, so they bypass auth and
      // are answered by the target handler directly.
      const isPreflight = req.method === 'OPTIONS';

      if (!isPreflight && !this.auth.isAuthorized(req, url.pathname, url.searchParams)) {
        req.log.warn('unauthorized request rejected', { pathname: url.pathname });
        sendJson(res, 401, { ok: false, error: 'unauthorized' }, { 'WWW-Authenticate': 'Bearer' });
        return;
      }

      const handler = this.routes.get(url.pathname);
      if (!handler) {
        req.log.warn('no route matched', { pathname: url.pathname });
        sendJson(res, 404, { ok: false, error: 'not_found' });
        return;
      }

      req.log.debug('dispatching to handler', { pathname: url.pathname });
      await handler(req, res, url);
    } catch (error) {
      req.log.error('unhandled error while handling request', { error });
      sendJson(res, 500, { ok: false, error: error.message });
    }
  }
}

module.exports = { Router };
