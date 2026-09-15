const httpClient = require('./httpClient');
const { rewriteManifest } = require('./manifestRewriter');
const { sendJson } = require('./httpResponse');

const UPSTREAM_HEADERS = { 'User-Agent': 'Mozilla/5.0' };

// Fetches upstream stream resources and, when they are HLS manifests, rewrites
// their URLs back through this proxy. Non-manifest content is streamed through
// untouched.
class StreamProxy {
  // Handles /proxy-stream: transparently proxies a segment or, if the target is
  // itself a manifest, rewrites it first.
  pipe(res, streamUrl, token) {
    const request = httpClient.get(streamUrl, { headers: UPSTREAM_HEADERS }, (upstream) => {
      const contentType = upstream.headers['content-type'] || '';
      const isManifest =
        contentType.includes('application/vnd.apple.mpegurl') ||
        contentType.includes('mpegurl') ||
        streamUrl.includes('.m3u8');

      if (isManifest) {
        this._collectAndRewrite(res, upstream, streamUrl, token);
      } else {
        res.writeHead(upstream.statusCode, {
          'Content-Type': contentType || 'application/octet-stream',
          'Access-Control-Allow-Origin': '*',
        });
        upstream.pipe(res);
      }
    });

    request.on('error', (err) => {
      sendJson(res, 502, { error: err.message });
    });
  }

  // Handles /proxy-m3u8: the target is always a manifest to be rewritten.
  serveManifest(res, manifestUrl, token) {
    const request = httpClient.get(manifestUrl, { headers: UPSTREAM_HEADERS }, (upstream) => {
      if (upstream.statusCode >= 400) {
        let body = '';
        upstream.on('data', (chunk) => {
          body += chunk;
        });
        upstream.on('end', () => {
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
      this._collectAndRewrite(res, upstream, manifestUrl, token);
    });

    request.on('error', (err) => {
      sendJson(res, 502, {
        error: 'Upstream manifest request error: ' + err.message,
        name: err.name,
        code: err.code,
        manifestUrl,
      });
    });
  }

  _collectAndRewrite(res, upstream, sourceUrl, token) {
    let body = '';
    upstream.on('data', (chunk) => {
      body += chunk;
    });
    upstream.on('end', () => {
      const rewritten = rewriteManifest(body, sourceUrl, {
        proxyPath: '/proxy-stream',
        tokenQuery: token ? '&token=' + encodeURIComponent(token) : '',
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
