const { randomUUID } = require('node:crypto');
const { Readable } = require('node:stream');

const DEFAULT_TIMEOUT_MS = 10000;
const DEFAULT_RESOURCE_TTL_MS = 30 * 60 * 1000;
const MAX_RESOURCE_COUNT = 10000;
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

class ResourceProxy {
  constructor({ providers, fetchImpl = globalThis.fetch, timeoutMs = DEFAULT_TIMEOUT_MS, resourceTtlMs = DEFAULT_RESOURCE_TTL_MS } = {}) {
    this.providers = providers;
    this.fetchImpl = fetchImpl;
    this.timeoutMs = timeoutMs;
    this.resourceTtlMs = resourceTtlMs;
    this.resources = new Map();
  }

  async serve(request, response, url, providerId) {
    const upstream = await this._fetchWithRetry(request, url, providerId);
    if (!upstream.ok && upstream.status !== 206) {
      await upstream.body?.cancel();
      response.writeHead(502).end(`Upstream returned ${upstream.status}`);
      return;
    }

    const contentType = upstream.headers.get('content-type') || '';
    if (/mpegurl/i.test(contentType) || /\.m3u8(?:\?|$)/i.test(upstream.url)) {
      const body = await upstream.text();
      if (!body.startsWith('#EXTM3U')) throw new Error('Invalid HLS playlist');
      response.writeHead(200, {
        'Content-Type': 'application/vnd.apple.mpegurl',
        'Cache-Control': 'no-store',
      });
      response.end(this._rewriteManifest(body, upstream.url, providerId));
      return;
    }

    const headers = { 'Content-Type': contentType || 'application/octet-stream', 'Cache-Control': 'no-store' };
    for (const name of ['content-range', 'accept-ranges']) {
      if (upstream.headers.has(name)) {
        headers[name === 'content-range' ? 'Content-Range' : 'Accept-Ranges'] = upstream.headers.get(name);
      }
    }
    response.writeHead(upstream.status, headers);
    Readable.fromWeb(upstream.body).on('error', () => response.destroy()).pipe(response);
  }

  async serveRegistered(request, response, key) {
    const resource = this._getResource(key);
    if (!resource) {
      response.writeHead(404).end();
      return;
    }
    await this.serve(request, response, resource.url, resource.providerId);
  }

  _register(url, providerId) {
    this._pruneExpired();
    if (this.resources.size >= MAX_RESOURCE_COUNT) {
      const oldestKey = this.resources.keys().next().value;
      if (oldestKey) this.resources.delete(oldestKey);
    }
    const key = randomUUID();
    this.resources.set(key, { url, providerId, expiresAt: Date.now() + this.resourceTtlMs });
    return `/resource/${key}`;
  }

  _getResource(key) {
    const resource = this.resources.get(key);
    if (!resource) return null;
    if (resource.expiresAt <= Date.now()) {
      this.resources.delete(key);
      return null;
    }
    return resource;
  }

  _pruneExpired() {
    const now = Date.now();
    for (const [key, resource] of this.resources) {
      if (resource.expiresAt <= now) this.resources.delete(key);
    }
  }

  _rewriteManifest(body, manifestUrl, providerId) {
    return body.split('\n').map((line) => {
      if (!line.trim()) return line;
      if (!line.startsWith('#')) return this._localUrl(line.trim(), manifestUrl, providerId);
      return line.replace(/URI="([^"]+)"/g, (_, uri) => `URI="${this._localUrl(uri, manifestUrl, providerId)}"`);
    }).join('\n');
  }

  _localUrl(uri, baseUrl, providerId) {
    return this._register(new URL(uri, baseUrl).href, providerId);
  }

  async _fetchWithRetry(request, url, providerId) {
    const provider = this.providers.get(providerId);
    const headers = {
      'User-Agent': USER_AGENT,
      Referer: `${provider.origin}/`,
      ...(request.headers.range ? { Range: request.headers.range } : {}),
    };
    let lastError;
    for (let attempt = 1; attempt <= 3; attempt++) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
      try {
        const response = await this.fetchImpl(url, { headers, signal: controller.signal });
        clearTimeout(timeout);
        if (response.ok || response.status === 206 || response.status < 500) return response;
        lastError = new Error(`Upstream returned ${response.status}`);
        await response.body?.cancel();
      } catch (error) {
        clearTimeout(timeout);
        lastError = error;
      }
      console.warn(`Upstream attempt ${attempt} failed for ${new URL(url).host}: ${lastError.message}`);
      await new Promise((resolve) => setTimeout(resolve, 300 * attempt));
    }
    throw lastError;
  }
}

module.exports = { ResourceProxy };