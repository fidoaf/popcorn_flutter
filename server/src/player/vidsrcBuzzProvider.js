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

  async extract(media) {
    const page = `${this.origin}/embed/${this._mediaPath(media)}`;
    const config = this._parseConfig(await (await this._get(page)).text());
    const refs = await this._serverRefs(config);
    if (!refs.length) throw new Error('No servers available');

    const raceUrl = new URL('/pl/api.php', this.origin);
    raceUrl.searchParams.set('a', 'race');
    raceUrl.searchParams.set('refs', refs.slice(0, 6).join(','));
    const race = await this._json(raceUrl);
    for (const candidate of race.cands || []) {
      try {
        const stream = await this._validate(candidate);
        return { page, ...stream };
      } catch (_) {
        // Continue to another candidate; failed servers are expected.
      }
    }

    for (const ref of refs) {
      try {
        const playUrl = new URL('/pl/api.php', this.origin);
        playUrl.searchParams.set('a', 'play');
        playUrl.searchParams.set('ref', ref);
        playUrl.searchParams.set('t', config.t);
        const candidate = await this._json(playUrl);
        if (candidate.url) return { page, ...(await this._validate(candidate)) };
      } catch (_) {
        // Try the next server.
      }
    }
    throw new Error('No playable stream found');
  }

  async listSubtitles(media) {
    const page = `${this.origin}/embed/${this._mediaPath(media)}`;
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

  async _serverRefs(config) {
    let servers = config.ssr?.servers || [];
    if (!servers.length) {
      const url = new URL('/pl/api.php', this.origin);
      url.search = new URLSearchParams({
        a: 'sources',
        type: String(config.type),
        id: String(config.id),
        s: String(config.s ?? 0),
        e: String(config.e ?? 0),
        t: String(config.t),
      });
      const sources = await this._json(url);
      servers = sources.servers || [];
    }
    return servers.map((server) => server.ref).filter(Boolean);
  }

  async _validate(candidate) {
    const url = new URL(candidate.url, this.origin);
    const response = await this._get(url);
    if (candidate.type !== 'mp4' && !(await response.text()).includes('#EXTM3U')) {
      throw new Error('Not an HLS playlist');
    }
    return { url: url.href, type: candidate.type || 'hls' };
  }

  async _json(url) {
    return (await this._get(url)).json();
  }

  async _get(url) {
    const response = await this.fetchImpl(url, {
      headers: { 'User-Agent': USER_AGENT, Referer: `${this.origin}/` },
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
}

module.exports = { VidSrcBuzzProvider };