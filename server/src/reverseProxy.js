const http = require('http');
const https = require('https');
const { sendJson } = require('./httpResponse');
const { createLogger } = require('./logger');

const moduleLog = createLogger('reverseProxy');

// Connection-scoped headers that must never be forwarded between hops.
const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'host',
]);

// Upstream response headers that restrict cross-origin access or embedding.
// They are dropped so the browser only ever sees the permissive policy below.
const SECURITY_STRIP = new Set([
  'x-frame-options',
  'content-security-policy',
  'content-security-policy-report-only',
  'cross-origin-opener-policy',
  'cross-origin-embedder-policy',
  'cross-origin-resource-policy',
]);

const PERMISSIVE_CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Expose-Headers': '*',
  'Access-Control-Max-Age': '86400',
};

function isCorsHeader(name) {
  return name.startsWith('access-control-') || name === 'timing-allow-origin';
}

// Reverse proxy that relays a request to an arbitrary upstream URL and strips
// every CORS/embedding restriction from the response, replacing them with a
// fully permissive policy. Redirects are followed internally so the client only
// ever talks to this proxy.
class ReverseProxy {
  constructor({ maxRedirects = 5 } = {}) {
    this.maxRedirects = maxRedirects;
  }

  // Answers a CORS preflight without contacting the upstream.
  preflight(res, log = moduleLog) {
    log.debug('preflight');
    res.writeHead(204, PERMISSIVE_CORS);
    res.end();
  }

  forward(req, res, targetUrl, log = moduleLog, redirectsLeft = this.maxRedirects) {
    let parsed;
    try {
      parsed = new URL(targetUrl);
    } catch (_) {
      sendJson(res, 400, { error: 'Invalid target url', url: targetUrl }, PERMISSIVE_CORS);
      return;
    }
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      sendJson(res, 400, { error: 'Unsupported protocol', protocol: parsed.protocol }, PERMISSIVE_CORS);
      return;
    }

    const client = parsed.protocol === 'https:' ? https : http;
    const options = {
      protocol: parsed.protocol,
      hostname: parsed.hostname,
      port: parsed.port,
      path: parsed.pathname + parsed.search,
      method: req.method,
      headers: this._buildUpstreamHeaders(req.headers, parsed),
    };

    log.info('forward upstream', { method: req.method, target: parsed.href });

    const upstream = client.request(options, (upRes) => {
      const status = upRes.statusCode;

      if (this._isRedirect(status) && upRes.headers.location && redirectsLeft > 0) {
        const nextUrl = new URL(upRes.headers.location, parsed).href;
        log.info('following redirect', { status, nextUrl, redirectsLeft });
        upRes.resume();
        this.forward(req, res, nextUrl, log, redirectsLeft - 1);
        return;
      }

      const contentType = upRes.headers['content-type'] || '';
      log.info('upstream response', { status, contentType: contentType || null });

      // HTML must be rewritten so the browser resolves relative and
      // root-relative asset URLs against the upstream origin instead of this
      // proxy, which would otherwise 404. Everything else is streamed as-is.
      if (contentType.includes('text/html')) {
        this._serveHtml(res, upRes, status, parsed.href, log);
        return;
      }

      res.writeHead(status, this._buildResponseHeaders(upRes.headers));
      upRes.pipe(res);
    });

    upstream.on('error', (err) => {
      log.error('upstream error', { target: parsed.href, error: err });
      if (!res.headersSent) {
        sendJson(res, 502, { error: 'Upstream request failed', detail: err.message }, PERMISSIVE_CORS);
      } else {
        res.destroy();
      }
    });

    if (req.method === 'GET' || req.method === 'HEAD') {
      upstream.end();
    } else {
      req.pipe(upstream);
    }
  }

  _isRedirect(status) {
    return status === 301 || status === 302 || status === 303 || status === 307 || status === 308;
  }

  // Buffers an HTML response, injects a <base> pointing at the final page URL so
  // relative/root-relative subresources resolve upstream, and sends it back.
  _serveHtml(res, upRes, status, pageUrl, log = moduleLog) {
    const chunks = [];
    upRes.on('data', (chunk) => chunks.push(chunk));
    upRes.on('end', () => {
      const html = Buffer.concat(chunks).toString('utf8');
      const rewritten = this._injectBase(html, pageUrl);
      const headers = this._buildResponseHeaders(upRes.headers);
      delete headers['content-length'];
      delete headers['content-encoding'];
      log.info('html rewritten', { pageUrl, originalBytes: html.length, rewrittenBytes: rewritten.length });
      res.writeHead(status, headers);
      res.end(rewritten);
    });
    upRes.on('error', (err) => {
      log.error('html read error', { pageUrl, error: err });
      if (!res.headersSent) sendJson(res, 502, { error: 'Upstream read failed', detail: err.message }, PERMISSIVE_CORS);
      else res.destroy();
    });
  }

  _injectBase(html, pageUrl) {
    const baseTag = `<base href="${pageUrl.replace(/"/g, '%22')}">`;
    const head = html.match(/<head[^>]*>/i);
    if (head) {
      const at = head.index + head[0].length;
      return html.slice(0, at) + baseTag + html.slice(at);
    }
    const htmlTag = html.match(/<html[^>]*>/i);
    if (htmlTag) {
      const at = htmlTag.index + htmlTag[0].length;
      return html.slice(0, at) + baseTag + html.slice(at);
    }
    return baseTag + html;
  }

  _buildUpstreamHeaders(incoming, parsed) {
    const headers = {};
    for (const [name, value] of Object.entries(incoming)) {
      if (HOP_BY_HOP.has(name.toLowerCase())) continue;
      headers[name] = value;
    }
    headers.host = parsed.host;
    // Force an unencoded body so HTML can be buffered and rewritten reliably.
    headers['accept-encoding'] = 'identity';
    return headers;
  }

  _buildResponseHeaders(upstreamHeaders) {
    const headers = {};
    for (const [name, value] of Object.entries(upstreamHeaders)) {
      const lower = name.toLowerCase();
      if (HOP_BY_HOP.has(lower)) continue;
      if (SECURITY_STRIP.has(lower)) continue;
      if (isCorsHeader(lower)) continue;
      headers[name] = value;
    }
    Object.assign(headers, PERMISSIVE_CORS);
    return headers;
  }
}

module.exports = { ReverseProxy };
