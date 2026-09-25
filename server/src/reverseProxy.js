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

const DEFAULT_USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

// Injected into proxied pages so third-party scripts calling the History API
// with the (cross-origin) upstream URL don't throw an uncaught SecurityError.
const HISTORY_GUARD =
  '<script>(function(){try{var h=window.history;["pushState","replaceState"].forEach(' +
  'function(m){var o=h[m];if(typeof o==="function"){h[m]=function(){try{return o.apply(this,arguments);}' +
  'catch(e){return;}};}});}catch(e){}})();</script>';

// Injected before any upstream script runs so programmatic requests like
// fetch('/vs_src.php') are transparently routed back through this proxy instead
// of escaping to the upstream origin and failing CORS in the browser.
const NETWORK_GUARD =
  '<script>(function(){try{' +
  'var origin=window.location.origin;' +
  'var proxyPrefix=origin+"/proxy?url=";' +
  'function bypass(value){return !value||/^(?:#|data:|blob:|javascript:|mailto:|tel:|about:blank)/i.test(String(value).trim());}' +
  'function isLocalProxy(url){try{var parsed=new URL(url,origin);return parsed.origin===origin&&(/^\\/proxy(?:$|[-/])/.test(parsed.pathname)||parsed.pathname==="/proxy");}catch(e){return false;}}' +
  'function proxify(value){' +
  'if(bypass(value))return value;' +
  'try{' +
  'var absolute=new URL(String(value),document.baseURI).href;' +
  'if(isLocalProxy(absolute))return absolute;' +
  'return proxyPrefix+encodeURIComponent(absolute);' +
  '}catch(e){return value;}' +
  '}' +
  'var originalFetch=window.fetch;' +
  'if(typeof originalFetch==="function"){' +
  'window.fetch=function(input,init){' +
  'try{' +
  'if(input&&typeof input==="object"&&typeof input.url==="string"){return originalFetch.call(this,new Request(proxify(input.url),input),init);}' +
  'return originalFetch.call(this,proxify(input),init);' +
  '}catch(e){return originalFetch.apply(this,arguments);}' +
  '};' +
  '}' +
  'if(window.XMLHttpRequest&&window.XMLHttpRequest.prototype&&typeof window.XMLHttpRequest.prototype.open==="function"){' +
  'var originalOpen=window.XMLHttpRequest.prototype.open;' +
  'window.XMLHttpRequest.prototype.open=function(method,url){try{arguments[1]=proxify(url);}catch(e){}return originalOpen.apply(this,arguments);};' +
  '}' +
  'if(window.navigator&&typeof window.navigator.sendBeacon==="function"){' +
  'var originalBeacon=window.navigator.sendBeacon;' +
  'window.navigator.sendBeacon=function(url,data){try{return originalBeacon.call(this,proxify(url),data);}catch(e){return originalBeacon.apply(this,arguments);}};' +
  '}' +
  'var originalSetAttribute=Element.prototype.setAttribute;' +
  'Element.prototype.setAttribute=function(name,value){' +
  'try{' +
  'var attr=String(name).toLowerCase();' +
  'if(/^(?:src|href|action|poster|data-api)$/.test(attr)){value=proxify(value);}' +
  'else if(attr==="srcset"){value=String(value).split(",").map(function(part){var bits=part.trim().split(/\\s+/);if(bits[0])bits[0]=proxify(bits[0]);return bits.join(" ");}).join(", ");}' +
  '}catch(e){}' +
  'return originalSetAttribute.call(this,name,value);' +
  '};' +
  '}catch(e){}})();</script>';

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
      const rewritten = this._rewriteHtml(html, pageUrl);
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

  _rewriteHtml(html, pageUrl) {
    const rewrittenUrls = this._rewriteMarkupUrls(html, pageUrl);
    return this._injectBase(rewrittenUrls, pageUrl);
  }

  _rewriteMarkupUrls(html, pageUrl) {
    const rewriteAttribute = (match, attr, quoted, doubleQuotedValue, singleQuotedValue) => {
      const quote = quoted[0];
      const originalValue = doubleQuotedValue ?? singleQuotedValue ?? '';
      const rewrittenValue = this._proxyMarkupUrl(originalValue, pageUrl);
      return `${attr}=${quote}${rewrittenValue}${quote}`;
    };

    const rewriteSrcset = (match, quoted, doubleQuotedValue, singleQuotedValue) => {
      const quote = quoted[0];
      const originalValue = doubleQuotedValue ?? singleQuotedValue ?? '';
      const rewrittenValue = originalValue
        .split(',')
        .map((candidate) => {
          const trimmed = candidate.trim();
          if (!trimmed) return trimmed;
          const [url, ...descriptor] = trimmed.split(/\s+/);
          const rewrittenUrl = this._proxyMarkupUrl(url, pageUrl);
          return descriptor.length > 0 ? `${rewrittenUrl} ${descriptor.join(' ')}` : rewrittenUrl;
        })
        .join(', ');
      return `srcset=${quote}${rewrittenValue}${quote}`;
    };

    return html
      .replace(/\b(src|action|poster|data-api)=("([^"]*)"|'([^']*)')/gi, rewriteAttribute)
      .replace(/\bsrcset=("([^"]*)"|'([^']*)')/gi, rewriteSrcset);
  }

  _proxyMarkupUrl(rawValue, pageUrl) {
    const value = String(rawValue || '').trim();
    if (!value || this._shouldBypassUrlRewrite(value)) return rawValue;

    try {
      const absolute = new URL(value, pageUrl).href;
      return '/proxy?url=' + encodeURIComponent(absolute);
    } catch (_) {
      return rawValue;
    }
  }

  _shouldBypassUrlRewrite(value) {
    return /^(?:#|data:|blob:|javascript:|mailto:|tel:|about:blank)/i.test(value);
  }

  _injectBase(html, pageUrl) {
    const baseTag = `<base href="${pageUrl.replace(/"/g, '%22')}">`;
    const head = html.match(/<head[^>]*>/i);
    if (head) {
      const at = head.index + head[0].length;
      return html.slice(0, at) + baseTag + NETWORK_GUARD + HISTORY_GUARD + html.slice(at);
    }
    const htmlTag = html.match(/<html[^>]*>/i);
    if (htmlTag) {
      const at = htmlTag.index + htmlTag[0].length;
      return html.slice(0, at) + baseTag + NETWORK_GUARD + HISTORY_GUARD + html.slice(at);
    }
    return baseTag + NETWORK_GUARD + HISTORY_GUARD + html;
  }

  _buildUpstreamHeaders(incoming, parsed) {
    const headers = {};
    for (const [name, value] of Object.entries(incoming)) {
      const lower = name.toLowerCase();
      if (HOP_BY_HOP.has(lower)) continue;
      // Don't leak the proxy's own origin to the upstream.
      if (lower === 'referer' || lower === 'origin') continue;
      headers[name] = value;
    }
    headers.host = parsed.host;
    // Present as a same-site browser request to reduce hotlink/bot rejections.
    headers.referer = parsed.origin + '/';
    if (!headers['user-agent']) headers['user-agent'] = DEFAULT_USER_AGENT;
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
