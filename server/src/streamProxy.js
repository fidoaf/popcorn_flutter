const httpClient = require('./httpClient');
const { rewriteManifest } = require('./manifestRewriter');
const { sendJson } = require('./httpResponse');
const { createLogger } = require('./logger');

const moduleLog = createLogger('streamProxy');

const UPSTREAM_HEADERS = { 'User-Agent': 'Mozilla/5.0' };

// Fetches upstream stream resources and, when they are HLS manifests, rewrites
// their URLs back through this proxy. Non-manifest content is streamed through
// untouched.
class StreamProxy {
  // Handles /proxy-stream: transparently proxies a segment or, if the target is
  // itself a manifest, rewrites it first.
  pipe(res, streamUrl, token, log = moduleLog) {
    log.debug('pipe upstream request', { streamUrl });
    const request = httpClient.get(streamUrl, { headers: UPSTREAM_HEADERS }, (upstream) => {
      const contentType = upstream.headers['content-type'] || '';
      const isManifest =
        contentType.includes('application/vnd.apple.mpegurl') ||
        contentType.includes('mpegurl') ||
        streamUrl.includes('.m3u8');

      log.info('pipe upstream response', {
        status: upstream.statusCode,
        contentType,
        isManifest,
      });

      if (isManifest) {
        this._collectAndRewrite(res, upstream, streamUrl, token, log);
      } else {
        res.writeHead(upstream.statusCode, {
          'Content-Type': contentType || 'application/octet-stream',
          'Access-Control-Allow-Origin': '*',
        });
        upstream.pipe(res);
      }
    });

    request.on('error', (err) => {
      log.error('pipe upstream error', { streamUrl, error: err });
      sendJson(res, 502, { error: err.message });
    });
  }

  // Handles /proxy-m3u8: the target is always a manifest to be rewritten.
  serveManifest(res, manifestUrl, token, log = moduleLog) {
    log.debug('serveManifest upstream request', { manifestUrl });
    const request = httpClient.get(manifestUrl, { headers: UPSTREAM_HEADERS }, (upstream) => {
      log.info('serveManifest upstream response', {
        status: upstream.statusCode,
        contentType: upstream.headers['content-type'] || null,
      });
      if (upstream.statusCode >= 400) {
        let body = '';
        upstream.on('data', (chunk) => {
          body += chunk;
        });
        upstream.on('end', () => {
          log.error('serveManifest upstream failed', {
            status: upstream.statusCode,
            manifestUrl,
            bodyPreview: body.slice(0, 500),
          });
          sendJson(res, 502, {
            error: 'Upstream manifest request failed',
            status: upstream.statusCode,
            manifestUrl,
            contentType: upstream.headers['content-type'] || null,
            bodyPreview: body.slice(0, 500),
          });
        });
        return;
      }
      this._collectAndRewrite(res, upstream, manifestUrl, token, log);
    });

    request.on('error', (err) => {
      log.error('serveManifest upstream error', { manifestUrl, error: err });
      sendJson(res, 502, {
        error: 'Upstream manifest request error: ' + err.message,
        name: err.name,
        code: err.code,
        manifestUrl,
      });
    });
  }

  _collectAndRewrite(res, upstream, sourceUrl, token, log = moduleLog) {
    let body = '';
    upstream.on('data', (chunk) => {
      body += chunk;
    });
    upstream.on('end', () => {
      const rewritten = rewriteManifest(body, sourceUrl, {
        proxyPath: '/proxy-stream',
        tokenQuery: token ? '&token=' + encodeURIComponent(token) : '',
      });
      log.info('manifest rewritten', {
        sourceUrl,
        originalBytes: body.length,
        rewrittenBytes: rewritten.length,
      });
      res.writeHead(200, {
        'Content-Type': 'application/vnd.apple.mpegurl',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'no-cache',
      });
      res.end(rewritten);
    });
  }
}

module.exports = { StreamProxy };
