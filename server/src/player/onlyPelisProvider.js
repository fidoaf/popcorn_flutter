const DEFAULT_TIMEOUT_MS = 10000;
const ONLYPELIS_ORIGIN = 'https://onlypelis.com';
const PLAYER_ORIGIN = 'https://paulinito.com';
const TMDB_ORIGIN = 'https://www.themoviedb.org';
const TMDB_TITLE_LANGUAGE = 'es-ES';
const STREAM_DOMAIN = '9bg.net';
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

class OnlyPelisProvider {
  constructor({ fetchImpl = globalThis.fetch, timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
    this.id = 'onlypelis';
    this.label = 'OnlyPelis';
    this.origin = PLAYER_ORIGIN;
    this.fetchImpl = fetchImpl;
    this.timeoutMs = timeoutMs;
    this.postIdCache = new Map();
  }

  async extract(media) {
    const html = await this._loadPlayerHtml(media);
    const streamUrl = parseHlsUrl(html);
    return { url: streamUrl.href, type: 'hls' };
  }

  async listSubtitles(media) {
    return parseSubtitleTracks(await this._loadPlayerHtml(media));
  }

  async fetchSubtitle(ref) {
    const url = validateSubtitleUrl(ref);
    const response = await this.fetchImpl(url, {
      headers: this._headers(PLAYER_ORIGIN),
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!response.ok) throw new Error(`OnlyPelis subtitle returned ${response.status}`);

    const contentType = response.headers.get('content-type') || '';
    const text = await response.text();
    if (contentType.toLowerCase().includes('text/html') || /<html[\s>]/i.test(text)) {
      throw new Error('OnlyPelis returned an HTML error page instead of subtitles');
    }
    return new Response(normalizeSubtitleText(text), {
      headers: { 'Content-Type': 'text/vtt; charset=utf-8' },
    });
  }

  async _loadPlayerHtml(media) {
    if (!['movie', 'tv'].includes(media.type)) {
      throw badRequest('OnlyPelis provider supports movies and TV episodes only');
    }
    if (!/^\d+$/.test(String(media.id))) {
      throw badRequest('OnlyPelis requires a numeric TMDB ID');
    }
    const postId = await this._resolvePostId(media);
    const playerUrl = await this._playerUrl(postId, media.type);
    return this._text(playerUrl, { headers: this._headers(ONLYPELIS_ORIGIN) });
  }

  async _resolvePostId(media) {
    const key = [media.type, media.id, media.season || '', media.episode || ''].join(':');
    if (this.postIdCache.has(key)) return this.postIdCache.get(key);

    const lookup = this._lookupPostId(media);
    this.postIdCache.set(key, lookup);
    try {
      return await lookup;
    } catch (error) {
      this.postIdCache.delete(key);
      throw error;
    }
  }

  async _lookupPostId(media) {
    const title = await this._tmdbTitle(media);
    const candidatePages = await this._searchPages(title, media.type);
    for (const candidateUrl of candidatePages.slice(0, 10)) {
      try {
        const candidateHtml = await this._text(candidateUrl, { headers: this._headers(ONLYPELIS_ORIGIN) });
        if (!sameTitle(title, parsePageHeading(candidateHtml))) continue;

        if (media.type === 'movie') {
          const postId = parsePostId(candidateHtml);
          if (postId) return postId;
          continue;
        }

        const episodeUrl = parseEpisodeUrl(candidateHtml, media.season, media.episode);
        if (!episodeUrl) continue;
        const episodeHtml = await this._text(episodeUrl, { headers: this._headers(ONLYPELIS_ORIGIN) });
        const postId = parsePostId(episodeHtml);
        if (postId) return postId;
      } catch (_) {
        // Continue in case search returned a stale or non-matching result.
      }
    }
    throw new Error(`OnlyPelis has no matching ${media.type} page for TMDB ID ${media.id}`);
  }

  async _tmdbTitle(media) {
    const url = new URL(`/${media.type}/${encodeURIComponent(media.id)}`, TMDB_ORIGIN);
    url.searchParams.set('language', TMDB_TITLE_LANGUAGE);
    const html = await this._text(url.href, {
      headers: { 'User-Agent': USER_AGENT, Accept: 'text/html' },
    });
    const title = parseMetaContent(html, 'og:title');
    if (!title) throw new Error(`TMDB returned no localized title for ${media.type} ID ${media.id}`);
    return title;
  }

  async _searchPages(title, type) {
    const url = new URL('/', ONLYPELIS_ORIGIN);
    url.searchParams.set('s', title);
    const html = await this._text(url.href, { headers: this._headers(ONLYPELIS_ORIGIN) });
    const pathPrefix = type === 'movie' ? '/pelicula/' : '/serie/';
    const pages = new Set();
    for (const match of html.matchAll(/\bhref\s*=\s*(["'])(.*?)\1/gi)) {
      try {
        const candidate = new URL(decodeHtml(match[2]), ONLYPELIS_ORIGIN);
        if (candidate.origin === ONLYPELIS_ORIGIN && candidate.pathname.startsWith(pathPrefix)) {
          candidate.search = '';
          candidate.hash = '';
          pages.add(candidate.href);
        }
      } catch (_) {
        // Ignore malformed links in the search response.
      }
    }
    return [...pages];
  }

  async _playerUrl(postId, type) {
    const body = new URLSearchParams({ action: 'doo_player_ajax', post: postId, nume: '1', type });
    const response = await this.fetchImpl(`${ONLYPELIS_ORIGIN}/wp-admin/admin-ajax.php`, {
      method: 'POST',
      headers: {
        ...this._headers(ONLYPELIS_ORIGIN),
        Accept: 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body,
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!response.ok) throw new Error(`OnlyPelis player lookup returned ${response.status}`);

    let result;
    try {
      result = await response.json();
    } catch (_) {
      throw new Error('OnlyPelis player lookup returned invalid JSON');
    }
    if (typeof result?.embed_url !== 'string') throw new Error('OnlyPelis did not return a player URL');

    const playerUrl = new URL(result.embed_url, ONLYPELIS_ORIGIN);
    if (playerUrl.protocol !== 'https:' || playerUrl.hostname !== 'paulinito.com' || !/^\/player\/[A-Za-z0-9_-]+\/?$/.test(playerUrl.pathname)) {
      throw new Error('OnlyPelis returned an unsupported player URL');
    }
    return playerUrl.href;
  }

  async _text(url, options) {
    const response = await this.fetchImpl(url, {
      ...options,
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!response.ok) throw new Error(`${new URL(url).hostname} returned ${response.status}`);
    return response.text();
  }

  _headers(referer) {
    return { 'User-Agent': USER_AGENT, Referer: `${referer}/` };
  }
}

function parseHlsUrl(html) {
  const match = html.match(/(?:\bsources\b|"sources"|'sources')\s*:\s*\[\s*\{\s*(?:\bfile\b|"file"|'file')\s*:\s*("(?:\\.|[^"\\])*")/s);
  if (!match) throw new Error('OnlyPelis player page contains no configured video source');

  let rawUrl;
  try {
    rawUrl = JSON.parse(match[1]);
  } catch (_) {
    throw new Error('OnlyPelis player page contains an invalid video URL');
  }

  const url = new URL(rawUrl);
  if (!isStreamUrl(url) || !url.pathname.toLowerCase().endsWith('.m3u8')) {
    throw new Error('OnlyPelis player page returned an unsupported HLS URL');
  }
  return url;
}

function parseSubtitleTracks(html) {
  const match = html.match(/(?:\btracks\b|"tracks"|'tracks')\s*:\s*\[([\s\S]*?)\]\s*(?:,|\})/);
  if (!match) return [];

  const subtitles = [];
  for (const entry of match[1].matchAll(/\{([^{}]*)\}/g)) {
    const fields = entry[1];
    const kind = readStringProperty(fields, 'kind')?.toLowerCase();
    if (!['captions', 'subtitles'].includes(kind)) continue;
    const rawUrl = readStringProperty(fields, 'file');
    if (!rawUrl) continue;

    let url;
    try {
      url = validateSubtitleUrl(rawUrl);
    } catch (_) {
      continue;
    }
    const label = readStringProperty(fields, 'label') || readStringProperty(fields, 'language') || `Subtitle ${subtitles.length + 1}`;
    subtitles.push({ ref: url.href, label, lang: readStringProperty(fields, 'language') || readStringProperty(fields, 'lang') || '' });
  }
  return subtitles;
}

function readStringProperty(source, name) {
  const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = source.match(new RegExp(`(?:\\b${escapedName}\\b|"${escapedName}"|'${escapedName}')\\s*:\\s*("(?:\\\\.|[^"\\\\])*")`));
  return match ? JSON.parse(match[1]) : null;
}

function validateSubtitleUrl(value) {
  const url = new URL(value);
  if (!isStreamUrl(url) || !/\.(?:srt|vtt)$/i.test(url.pathname)) {
    throw new Error('OnlyPelis returned an unsupported subtitle URL');
  }
  return url;
}

function isStreamUrl(url) {
  return url.protocol === 'https:' && (url.hostname === STREAM_DOMAIN || url.hostname.endsWith(`.${STREAM_DOMAIN}`));
}

function normalizeSubtitleText(value) {
  const text = String(value || '').replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n').trim();
  if (/^WEBVTT(?:\s|$)/i.test(text)) return `${text}\n`;
  if (!/^\d{2}:\d{2}:\d{2}[,.]\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}[,.]\d{3}/m.test(text)) {
    throw new Error('OnlyPelis subtitle is not valid SRT or WebVTT');
  }
  const cues = text
    .replace(/^\d+\s*$/gm, '')
    .replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2')
    .trim();
  return `WEBVTT\n\n${cues}\n`;
}

function parseMetaContent(html, property) {
  for (const tag of html.matchAll(/<meta\b[^>]*>/gi)) {
    if (!new RegExp(`\\bproperty\\s*=\\s*(["'])${property}\\1`, 'i').test(tag[0])) continue;
    const content = tag[0].match(/\bcontent\s*=\s*(["'])(.*?)\1/i);
    if (content) return decodeHtml(content[2]).trim();
  }
  return '';
}

function parsePageHeading(html) {
  const match = html.match(/<h1\b[^>]*>([\s\S]*?)<\/h1>/i);
  return match ? decodeHtml(match[1].replace(/<[^>]*>/g, ' ')).trim() : '';
}

function parsePostId(html) {
  const match = html.match(/<body\b[^>]*\bclass\s*=\s*(["'])[^"']*\bpostid-(\d+)\b[^"']*\1/i);
  return match?.[2] || null;
}

function parseEpisodeUrl(html, season, episode) {
  const suffix = new RegExp(`-${Number(season)}x${Number(episode)}/?$`, 'i');
  for (const match of html.matchAll(/\bhref\s*=\s*(["'])(.*?)\1/gi)) {
    try {
      const url = new URL(decodeHtml(match[2]), ONLYPELIS_ORIGIN);
      if (url.origin === ONLYPELIS_ORIGIN && url.pathname.startsWith('/episodios/') && suffix.test(url.pathname)) {
        url.search = '';
        url.hash = '';
        return url.href;
      }
    } catch (_) {
      // Ignore malformed links in the series page.
    }
  }
  return null;
}

function sameTitle(expected, actual) {
  return normalizeTitle(expected) === normalizeTitle(actual);
}

function normalizeTitle(value) {
  return decodeHtml(value)
    .replace(/\s*\(\d{4}\)\s*$/, '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function decodeHtml(value) {
  return String(value).replace(/&(#x[\da-f]+|#\d+|amp|quot|apos|lt|gt|nbsp|aacute|eacute|iacute|oacute|uacute|ntilde|uuml|Aacute|Eacute|Iacute|Oacute|Uacute|Ntilde|Uuml);/gi, (entity, code) => {
    if (code[0] === '#') {
      const point = code[1]?.toLowerCase() === 'x' ? Number.parseInt(code.slice(2), 16) : Number.parseInt(code.slice(1), 10);
      return Number.isFinite(point) ? String.fromCodePoint(point) : entity;
    }
    return ({ amp: '&', quot: '"', apos: "'", lt: '<', gt: '>', nbsp: ' ', aacute: 'á', eacute: 'é', iacute: 'í', oacute: 'ó', uacute: 'ú', ntilde: 'ñ', uuml: 'ü', Aacute: 'Á', Eacute: 'É', Iacute: 'Í', Oacute: 'Ó', Uacute: 'Ú', Ntilde: 'Ñ', Uuml: 'Ü' })[code] || entity;
  });
}

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

module.exports = { OnlyPelisProvider, parseHlsUrl, parseSubtitleTracks };