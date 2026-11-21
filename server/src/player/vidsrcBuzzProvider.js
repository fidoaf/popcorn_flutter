const DEFAULT_TIMEOUT_MS = 10000;
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

class VidSrcBuzzProvider {
  constructor({ fetchImpl = globalThis.fetch, timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
    this.id = 'vidsrcbuzz';
    this.label = 'VidSrc.buzz';
    this.origin = 'https://vidsrc.buzz';
    this.fetchImpl = fetchImpl;
    this.timeoutMs = timeoutMs;
  }

  async extract(media, selectedSource = null) {
    const page = this._embedUrl(media);
    const config = this._parseConfig(await (await this._get(page)).text());
    if (selectedSource) {
      const playUrl = new URL('/pl/api.php', this.origin);
      playUrl.search = new URLSearchParams({ a: 'play', ref: selectedSource.ref, t: selectedSource.token });
      const candidate = await this._json(playUrl);
      if (!candidate.url) throw new Error('Selected server did not return a playable stream');
      return { page, ...(await this._validate(candidate)) };
    }
    const { servers: initialServers } = await this._servers(config);
    const refs = refsOf(initialServers);
    const tried = new Set(initialServers.map(serverKey));

    if (refs.length) {
      const raceUrl = new URL('/pl/api.php', this.origin);
      raceUrl.searchParams.set('a', 'race');
      raceUrl.searchParams.set('refs', refs.slice(0, 6).join(','));
      let race = {};
      try {
        race = await this._json(raceUrl);
      } catch (_) {
        // The race endpoint intermittently answers 502; fall back to per-server play.
      }
      for (const candidate of race.cands || []) {
        try {
          const stream = await this._validate(candidate);
          return { page, ...stream };
        } catch (_) {
          // Continue to another candidate; failed servers are expected.
        }
      }

      const stream = await this._playFirst(refs, config.t);
      if (stream) return { page, ...stream };
    }

    // Like the embed page, fall back to the "last resort" server list, which
    // can expose servers that the initial list omits.
    const extraRefs = refsOf((await this._lastResortServers(config)).filter((server) => !tried.has(serverKey(server))));
    if (!refs.length && !extraRefs.length) throw new Error('No servers available');
    const stream = await this._playFirst(extraRefs, config.t);
    if (stream) return { page, ...stream };
    throw new Error('No playable stream found');
  }

  async _playFirst(refs, token) {
    for (const ref of refs) {
      try {
        const playUrl = new URL('/pl/api.php', this.origin);
        playUrl.search = new URLSearchParams({ a: 'play', ref, t: token });
        const candidate = await this._json(playUrl);
        if (candidate.url) return await this._validate(candidate);
      } catch (_) {
        // Try the next server.
      }
    }
    return null;
  }

  async listSources(media) {
    const page = this._embedUrl(media);
    const config = this._parseConfig(await (await this._get(page)).text());
    const { servers: initial, more } = await this._servers(config);
    const servers = [...initial];
    if (more) {
      const known = new Set(initial.map(serverKey));
      for (const server of await this._lastResortServers(config)) {
        if (server?.ref && !known.has(serverKey(server))) servers.push(server);
      }
    }
    return {
      token: config.t,
      sources: servers.filter((server) => typeof server.ref === 'string' && server.ref).map((server) => ({
        ref: server.ref,
        name: typeof server.name === 'string' && server.name ? server.name : 'Streaming server',
        lang: typeof server.lang === 'string' ? server.lang : '',
        flag: typeof server.flag === 'string' ? server.flag : '',
      })),
    };
  }

  async listSubtitles(media) {
    const page = this._embedUrl(media);
    const config = this._parseConfig(await (await this._get(page)).text());
    const url = new URL('/pl/api.php', this.origin);
    url.search = new URLSearchParams({
      a: 'subs',
      type: String(config.type),
      id: String(config.id),
      s: String(config.s ?? 0),
      e: String(config.e ?? 0),
      t: String(config.t),
    });
    const result = await this._json(url);
    return Array.isArray(result.subs) ? result.subs : [];
  }

  async fetchSubtitle(ref) {
    const url = new URL('/pl/api.php', this.origin);
    url.search = new URLSearchParams({ a: 'sub', ref });
    return this._get(url);
  }

  async _servers(config) {
    const servers = config.ssr?.servers || [];
    if (servers.length) return { servers, more: Boolean(config.ssr.more) };
    const sources = await this._json(this._sourcesUrl(config));
    return { servers: sources.servers || [], more: Boolean(sources.more) };
  }

  async _lastResortServers(config) {
    try {
      const sources = await this._json(this._sourcesUrl(config, { pf: '1' }));
      return Array.isArray(sources.servers) ? sources.servers : [];
    } catch (_) {
      return [];
    }
  }

  _sourcesUrl(config, extra = {}) {
    const url = new URL('/pl/api.php', this.origin);
    url.search = new URLSearchParams({
      a: 'sources',
      type: String(config.type),
      id: String(config.id),
      s: String(config.s ?? 0),
      e: String(config.e ?? 0),
      t: String(config.t),
      ...extra,
    });
    return url;
  }

  async _validate(candidate) {
    const url = new URL(candidate.url, this.origin);
    const response = await this._get(url);
    if (candidate.type !== 'mp4') {
      const playlist = await response.text();
      if (!playlist.includes('#EXTM3U')) throw new Error('Not an HLS playlist');
      await this._probeFirstSegment(playlist, new URL(response.url || url.href));
    } else {
      await response.body?.cancel();
    }
    return { url: url.href, type: candidate.type || 'hls' };
  }

  // Some relays serve a valid playlist whose segments are gone upstream, which
  // only surfaces in the browser as hls.js fragLoadError; reject those early.
  async _probeFirstSegment(playlist, baseUrl) {
    let body = playlist;
    let base = baseUrl;
    if (body.includes('#EXT-X-STREAM-INF')) {
      const variant = this._firstUri(body);
      if (!variant) return;
      const response = await this._get(new URL(variant, base));
      body = await response.text();
      base = new URL(response.url || new URL(variant, base).href);
      if (!body.includes('#EXTM3U')) throw new Error('Variant is not an HLS playlist');
    }
    const segment = this._firstUri(body);
    if (!segment) return;
    const segmentUrl = new URL(segment, base);
    const direct = this.directUpstream(segmentUrl.href);
    if (direct) {
      try {
        const response = await this._get(direct.url, direct.referer);
        await response.body?.cancel();
        return;
      } catch (_) {
        // Fall back to the relay URL below.
      }
    }
    const response = await this._get(segmentUrl);
    await response.body?.cancel();
  }

  // VidSrc.buzz playlists route segments through a relay (`/seg?u=<origin>&r=<referer>`)
  // that is slow and often answers 503, while relaying the origin bytes unchanged.
  directUpstream(url) {
    let parsed;
    try {
      parsed = new URL(url);
    } catch (_) {
      return null;
    }
    if (parsed.pathname !== '/seg') return null;
    const target = httpUrl(parsed.searchParams.get('u'));
    if (!target) return null;
    return { url: target, referer: httpUrl(parsed.searchParams.get('r')) };
  }

  _firstUri(playlist) {
    return playlist.split('\n').map((line) => line.trim()).find((line) => line && !line.startsWith('#')) || null;
  }

  async _json(url) {
    return (await this._get(url)).json();
  }

  async _get(url, referer = `${this.origin}/`) {
    const response = await this.fetchImpl(url, {
      headers: { 'User-Agent': USER_AGENT, ...(referer ? { Referer: referer } : {}) },
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!response.ok) throw new Error(`${response.status} ${response.statusText} from ${new URL(url).pathname}`);
    return response;
  }

  _parseConfig(html) {
    const match = html.match(/var Q\s*=\s*(\{.*?\});/s);
    if (!match) throw new Error('Player config Q not found in embed page');
    return JSON.parse(match[1]);
  }

  _mediaPath(media) {
    return media.type === 'movie'
      ? `movie/${encodeURIComponent(media.id)}`
      : `tv/${encodeURIComponent(media.id)}/${encodeURIComponent(media.season)}/${encodeURIComponent(media.episode)}`;
  }

  _embedUrl(media) {
    const url = new URL(`/embed/${this._mediaPath(media)}`, this.origin);
    url.searchParams.set('lang', media.lang || 'en');
    url.searchParams.set('sub', media.sub ?? '1');
    return url;
  }
}

function refsOf(servers) {
  return servers.map((server) => server?.ref).filter((ref) => typeof ref === 'string' && ref);
}

// Refs are re-signed on every API response, so prefer the stable server key.
function serverKey(server) {
  return server?.k || server?.ref;
}

function httpUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.href : null;
  } catch (_) {
    return null;
  }
}

module.exports = { VidSrcBuzzProvider };