const CHANNELS_URL = 'https://iptv-org.github.io/api/channels.json';
const STREAMS_URL = 'https://iptv-org.github.io/api/streams.json';
const LOGOS_URL = 'https://iptv-org.github.io/api/logos.json';
const CACHE_TTL_MS = 6 * 60 * 60 * 1000;
const MAX_CHANNELS = 60;

function parseHttpUrl(value) {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value);
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) return null;
    return url.toString();
  } catch {
    return null;
  }
}

function normalizeHeaders(stream) {
  const headers = {};
  if (typeof stream.http_referrer === 'string' && stream.http_referrer.trim()) {
    headers.Referer = stream.http_referrer.trim();
  }
  if (typeof stream.user_agent === 'string' && stream.user_agent.trim()) {
    headers['User-Agent'] = stream.user_agent.trim();
  }
  return headers;
}

function logoPriority(logo) {
  const tags = Array.isArray(logo.tags) ? logo.tags : [];
  return (logo.in_use === true ? 4 : 0) + (tags.includes('horizontal') ? 2 : 0) + (tags.includes('white') ? 1 : 0);
}

function indexLogos(logos) {
  const byChannel = new Map();
  for (const logo of logos) {
    if (typeof logo?.channel !== 'string') continue;
    const url = parseHttpUrl(logo.url);
    if (!url) continue;
    let byFeed = byChannel.get(logo.channel);
    if (!byFeed) {
      byFeed = new Map();
      byChannel.set(logo.channel, byFeed);
    }
    const feed = typeof logo.feed === 'string' ? logo.feed : '';
    const previous = byFeed.get(feed);
    if (!previous || logoPriority(logo) > previous.priority) {
      byFeed.set(feed, {
        url,
        format: typeof logo.format === 'string' ? logo.format : null,
        priority: logoPriority(logo),
      });
    }
  }
  return byChannel;
}

class LiveTvCatalog {
  constructor({ fetchImpl = fetch, now = Date.now, ttlMs = CACHE_TTL_MS, maxChannels = MAX_CHANNELS } = {}) {
    this.fetchImpl = fetchImpl;
    this.now = now;
    this.ttlMs = ttlMs;
    this.maxChannels = maxChannels;
    this.channels = null;
    this.expiresAt = 0;
    this.inFlight = null;
  }

  async getChannels(country = '') {
    const channels = await this._getAllChannels();
    return channels.filter((channel) => !country || channel.country === country).slice(0, this.maxChannels);
  }

  async getChannel(id) {
    return (await this._getAllChannels()).find((channel) => channel.id === id);
  }

  async getCatalogue({ country = '', channelId = null, query = '' } = {}) {
    const allChannels = await this._getAllChannels();
    const displayNames = new Map(['en', 'es', 'ca'].map((language) => [language, new Intl.DisplayNames([language], { type: 'region' })]));
    const countries = [...new Set(allChannels.map((channel) => channel.country))]
      .filter((code) => /^[A-Z]{2}$/.test(code))
      .map((code) => ({
        code,
        name: displayNames.get('en').of(code),
        names: Object.fromEntries([...displayNames].map(([language, names]) => [language, names.of(code)])),
        flag: String.fromCodePoint(...[...code].map((letter) => letter.charCodeAt(0) + 127397)),
      }))
      .sort((a, b) => a.name.localeCompare(b.name));
    const channels = allChannels
      .filter((channel) => channelId !== null ? channel.id === channelId : !country || channel.country === country)
      .filter((channel) => !query.trim() || channel.name.toLowerCase().includes(query.trim().toLowerCase()) || channel.id.toLowerCase().includes(query.trim().toLowerCase()))
      .slice(0, this.maxChannels);
    return { channels, countries };
  }

  async _getAllChannels() {
    if (this.channels && this.expiresAt > this.now()) return this.channels;
    if (this.inFlight) return this.inFlight;

    this.inFlight = this._loadChannels()
      .then((channels) => {
        this.channels = channels;
        this.expiresAt = this.now() + this.ttlMs;
        return channels;
      })
      .finally(() => {
        this.inFlight = null;
      });

    return this.inFlight;
  }

  async _loadChannels() {
    const [channelsResponse, streamsResponse, logosResponse] = await Promise.all([
      this.fetchImpl(CHANNELS_URL, { signal: AbortSignal.timeout(15000) }),
      this.fetchImpl(STREAMS_URL, { signal: AbortSignal.timeout(15000) }),
      this.fetchImpl(LOGOS_URL, { signal: AbortSignal.timeout(15000) }),
    ]);
    if (!channelsResponse.ok || !streamsResponse.ok || !logosResponse.ok) {
      throw new Error(`iptv-org catalogue request failed (channels: ${channelsResponse.status}, streams: ${streamsResponse.status}, logos: ${logosResponse.status})`);
    }

    const [channels, streams, logos] = await Promise.all([channelsResponse.json(), streamsResponse.json(), logosResponse.json()]);
    if (!Array.isArray(channels) || !Array.isArray(streams) || !Array.isArray(logos)) {
      throw new TypeError('iptv-org returned an invalid catalogue format');
    }

    const logosByChannel = indexLogos(logos);
    const channelById = new Map();
    for (const channel of channels) {
      if (typeof channel?.id !== 'string' || typeof channel.name !== 'string' || !channel.name.trim()) continue;
      channelById.set(channel.id, {
        id: channel.id,
        name: channel.name.trim(),
        country: typeof channel.country === 'string' ? channel.country : '',
        website: parseHttpUrl(channel.website),
        network: typeof channel.network === 'string' ? channel.network : '',
        languages: Array.isArray(channel.languages) ? channel.languages.filter((value) => typeof value === 'string') : [],
        categories: Array.isArray(channel.categories) ? channel.categories.filter((value) => typeof value === 'string') : [],
      });
    }

    const streamByChannel = new Map();
    for (const stream of streams) {
      if (typeof stream?.channel !== 'string' || streamByChannel.has(stream.channel)) continue;
      const url = parseHttpUrl(stream.url);
      if (!url || !channelById.has(stream.channel)) continue;
      const byFeed = logosByChannel.get(stream.channel);
      const feed = typeof stream.feed === 'string' ? stream.feed : '';
      const logo = byFeed?.get(feed) ?? byFeed?.get('');
      streamByChannel.set(stream.channel, {
        feed,
        url,
        headers: normalizeHeaders(stream),
        logo: logo?.url ?? null,
        logoFormat: logo?.format ?? null,
      });
    }

    return [...streamByChannel.entries()]
      .map(([id, stream]) => ({ ...channelById.get(id), ...stream }))
      .sort((first, second) => first.name.localeCompare(second.name));
  }
}

module.exports = { LiveTvCatalog };
