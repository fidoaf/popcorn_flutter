const { SaxesParser } = require('saxes');

const GUIDES_URL = 'https://iptv-epg.org/guides';
const MAX_GUIDE_BYTES = 256 * 1024 * 1024;

function xmltvDate(value) {
  const match = String(value).match(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*(Z|[+-]\d{4})?$/);
  if (!match) return null;
  const [, year, month, day, hour, minute, second = '00', zone = 'Z'] = match;
  const offset = zone === 'Z' ? 'Z' : `${zone.slice(0, 3)}:${zone.slice(3)}`;
  const date = new Date(`${year}-${month}-${day}T${hour}:${minute}:${second}${offset}`);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function text(value) {
  const first = Array.isArray(value) ? value[0] : value;
  return typeof first === 'object' && first !== null ? String(first['#text'] ?? '') : String(first ?? '');
}

function normalizedName(value) {
  return value.replace(/^[A-Z]{2}\s*-\s*/i, '').normalize('NFKC').toLocaleLowerCase('en').replace(/\s+/g, ' ').trim();
}

function matchingChannelIds(entries, channel) {
  const feedId = channel.feed ? `${channel.id}@${channel.feed}` : null;
  if (feedId && entries.some((entry) => entry['@_id'] === feedId)) return new Set([feedId]);
  if (entries.some((entry) => entry['@_id'] === channel.id)) return new Set([channel.id]);
  if (!channel.name) return new Set();
  const name = normalizedName(channel.name);
  const matches = entries.filter((entry) => {
    const names = Array.isArray(entry['display-name']) ? entry['display-name'] : [entry['display-name']];
    return names.some((value) => normalizedName(text(value)) === name);
  });
  // Never merge schedules when a display name identifies multiple feeds.
  return matches.length === 1 ? new Set([matches[0]['@_id']]) : new Set();
}

function parseProgrammes(xml, channel, now) {
  const guide = createGuideParser(now);
  guide.parser.write(xml).close();
  return programmesFromGuide(guide.result(), channel, now);
}

function programmesFromGuide(parsed, channel, now) {
  const ids = matchingChannelIds(parsed.tv.channel ?? [], channel);
  return (parsed.tv.programme ?? [])
    .filter((entry) => ids.has(entry['@_channel']))
    .map((entry) => ({
      title: text(entry.title),
      description: text(entry.desc),
      start: xmltvDate(entry['@_start']),
      end: xmltvDate(entry['@_stop']),
    }))
    .filter((entry) => entry.title && entry.start && entry.end && entry.end > entry.start && Date.parse(entry.end) > now)
    .sort((a, b) => a.start.localeCompare(b.start))
    .slice(0, 100);
}

function createGuideParser(now) {
  const parser = new SaxesParser();
  const channels = [];
  const programmes = new Map();
  let depth = 0;
  let hasTv = false;
  let entry = null;
  let entryDepth = 0;
  let field = null;
  let fieldDepth = 0;
  let content = '';
  parser.on('doctype', () => { throw new Error('Invalid XMLTV guide: DOCTYPE is not supported'); });
  parser.on('error', (error) => { throw new Error(`Invalid XMLTV guide: ${error.message}`); });
  parser.on('opentag', (tag) => {
    depth += 1;
    if (depth === 1) {
      if (tag.name !== 'tv') throw new Error('Invalid XMLTV guide: missing tv element');
      hasTv = true;
    }
    if (depth === 2 && (tag.name === 'channel' || tag.name === 'programme')) {
      entry = Object.fromEntries(Object.entries(tag.attributes).map(([key, value]) => [`@_${key}`, value]));
      entryDepth = depth;
    } else if (entry && depth === entryDepth + 1 && ['title', 'desc', 'display-name'].includes(tag.name)) {
      field = tag.name;
      fieldDepth = depth;
      content = '';
    }
  });
  const append = (value) => {
    if (field) content += value.slice(0, Math.max(0, 65536 - content.length));
  };
  parser.on('text', append);
  parser.on('cdata', append);
  parser.on('closetag', (tag) => {
    if (field && depth === fieldDepth) {
      if (field === 'display-name') (entry[field] ??= []).push(content);
      else if (entry[field] === undefined) entry[field] = content;
      field = null;
    }
    if (entry && depth === entryDepth) {
      if (tag.name === 'channel') channels.push(entry);
      else {
        const start = xmltvDate(entry['@_start']);
        const end = xmltvDate(entry['@_stop']);
        if (entry.title && start && end && end > start && Date.parse(end) > now) {
          const id = entry['@_channel'];
          if (!programmes.has(id)) programmes.set(id, []);
          const rows = programmes.get(id);
          entry.startUtc = start;
          rows.push(entry);
          rows.sort((a, b) => a.startUtc.localeCompare(b.startUtc));
          if (rows.length > 100) rows.pop();
        }
      }
      entry = null;
    }
    depth -= 1;
  });
  return {
    parser,
    result() {
      if (!hasTv) throw new Error('Invalid XMLTV guide: missing tv element');
      return { tv: { channel: channels, programme: [...programmes.values()].flat() } };
    },
  };
}

async function readGuide(response, now) {
  const guide = createGuideParser(now);
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > MAX_GUIDE_BYTES) throw new Error('EPG source exceeds size limit');
      guide.parser.write(decoder.decode(value, { stream: true }));
    }
    guide.parser.write(decoder.decode()).close();
    return guide.result();
  } finally {
    await reader.cancel();
  }
}

class LiveTvEpg {
  constructor({ fetchImpl = fetch, now = Date.now } = {}) {
    this.fetchImpl = fetchImpl;
    this.now = now;
    this.guides = null;
    this.guidesExpires = 0;
    this.guidesLoad = null;
    this.sources = new Map();
  }

  async _guides() {
    if (this.guides && this.guidesExpires > this.now()) return this.guides;
    if (!this.guidesLoad) {
      this.guidesLoad = (async () => {
        const response = await this.fetchImpl(GUIDES_URL, { signal: AbortSignal.timeout(15000) });
        if (!response.ok) throw new Error(`EPG directory request failed (${response.status})`);
        const html = await response.text();
        const guides = new Map();
        for (const match of html.matchAll(/https:\/\/iptv-epg\.org\/files\/epg-([a-z]{2})\.xml(?=["'\s<])/g)) {
          guides.set(match[1].toUpperCase(), match[0]);
        }
        if (guides.size === 0) throw new Error('Invalid IPTV-EPG guide directory: no country guides found');
        this.guides = guides;
        this.guidesExpires = this.now() + 6 * 60 * 60 * 1000;
        return guides;
      })().finally(() => { this.guidesLoad = null; });
    }
    return this.guidesLoad;
  }

  async _guide(url) {
    const cached = this.sources.get(url);
    if (cached && cached.expires > this.now()) return cached.promise;
    if (this.sources.size >= 4) this.sources.delete(this.sources.keys().next().value);
    const entry = { expires: Infinity };
    entry.promise = (async () => {
      const response = await this.fetchImpl(url, { signal: AbortSignal.timeout(30000) });
      if (!response.ok) throw new Error(`EPG source request failed (${response.status})`);
      const guide = await readGuide(response, this.now());
      entry.expires = this.now() + 15 * 60 * 1000;
      return guide;
    })().catch((error) => {
      if (this.sources.get(url) === entry) this.sources.delete(url);
      throw error;
    });
    this.sources.set(url, entry);
    return entry.promise;
  }

  async getProgrammes(channel) {
    if (typeof channel.country !== 'string' || !/^[A-Z]{2}$/.test(channel.country)) return [];
    const url = (await this._guides()).get(channel.country);
    if (!url) return [];
    try {
      return programmesFromGuide(await this._guide(url), channel, this.now());
    } catch (error) {
      this.sources.delete(url);
      throw error;
    }
  }
}

module.exports = { LiveTvEpg, parseProgrammes };
