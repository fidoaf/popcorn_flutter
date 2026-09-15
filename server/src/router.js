const { sendJson } = require('./httpResponse');

// Maps request paths to controller methods and enforces auth before dispatch.
// Adding an endpoint means registering a route here — handlers don't know about
// routing or authorization concerns (Single Responsibility).
class Router {
  constructor({ auth }) {
    this.auth = auth;
    this.routes = new Map();
  }

  register(pathname, handler) {
    this.routes.set(pathname, handler);
    return this;
  }

  async handle(req, res) {
    try {
      const url = new URL(req.url, `http://${req.headers.host}`);

      if (!this.auth.isAuthorized(req, url.pathname, url.searchParams)) {
        sendJson(res, 401, { ok: false, error: 'unauthorized' }, { 'WWW-Authenticate': 'Bearer' });
        return;
      }

      const handler = this.routes.get(url.pathname);
      if (!handler) {
        sendJson(res, 404, { ok: false, error: 'not_found' });
        return;
      }

      await handler(req, res, url);
    } catch (error) {
      sendJson(res, 500, { ok: false, error: error.message });
    }
  }
}

module.exports = { Router };
