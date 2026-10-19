const { Resolver } = require('node:dns/promises');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TTL_MS = 60 * 60 * 1000;
const COUNTRY_NAMES = new Map(['en', 'es', 'ca'].map((language) => [language, new Intl.DisplayNames([language], { type: 'region' })]));

function httpUrl(value) {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value);
    return ['http:', 'https:'].includes(url.protocol) && !url.username && !url.password ? url.href : null;
  } catch {
    return null;
  }
}

function normalizeStation(station) {
  if (!station || !UUID.test(station.stationuuid) || typeof station.name !== 'string' || !station.name.trim()) return null;
  const url = httpUrl(station.url_resolved) || httpUrl(station.url);
  if (!url || station.lastcheckok !== 1) return null;
  return {
    id: station.stationuuid,
    name: station.name.trim(),
    url,
    logo: httpUrl(station.favicon),
    website: httpUrl(station.homepage),
    country: typeof station.country === 'string' ? station.country : '',
    countryCode: typeof station.countrycode === 'string' ? station.countrycode : '',
    languages: typeof station.language === 'string' ? station.language.split(',').map((value) => value.trim()).filter(Boolean) : [],
    tags: typeof station.tags === 'string' ? station.tags.split(',').map((value) => value.trim()).filter(Boolean) : [],
    codec: typeof station.codec === 'string' ? station.codec : '',
    bitrate: Number.isFinite(station.bitrate) && station.bitrate > 0 ? station.bitrate : 0,
  };
}

class RadioCatalog {
  constructor({
    fetchImpl = fetch,
    resolveServers = () => new Resolver({ timeout: 3000, tries: 1 }).resolveSrv('_api._tcp.radio-browser.info'),
    now = Date.now,
    random = Math.random,
  } = {}) {
    this.fetchImpl = fetchImpl;
    this.resolveServers = resolveServers;
    this.now = now;
    this.random = random;
    this.servers = null;
    this.serversExpireAt = 0;
    this.discovery = null;
    this.catalogues = new Map();
    this.inFlight = new Map();
    this.countries = null;
    this.countriesExpireAt = 0;
    this.countriesInFlight = null;
  }

  async _servers() {
    if (this.servers && this.serversExpireAt > this.now()) return this.servers;
    if (this.discovery) return this.discovery;
    this.discovery = (async () => {
      const records = await this.resolveServers();
      const servers = [...new Set(records.map((record) => record.name)
        .filter((name) => typeof name === 'string' && /^[a-z0-9-]+\.api\.radio-browser\.info$/i.test(name)))];
      if (!servers.length) throw new Error('Radio Browser discovery returned no servers');
      for (let index = servers.length - 1; index > 0; index -= 1) {
        const other = Math.floor(this.random() * (index + 1));
        [servers[index], servers[other]] = [servers[other], servers[index]];
      }
      this.servers = servers.slice(0, 3);
      this.serversExpireAt = this.now() + TTL_MS;
      return this.servers;
    })().finally(() => { this.discovery = null; });
    return this.discovery;
  }

  async _request(path, validate) {
    const errors = [];
    for (const host of await this._servers()) {
      try {
        const response = await this.fetchImpl(`https://${host}${path}`, {
          headers: { Accept: 'application/json', 'User-Agent': 'PopcornFlutter/1.0 (Radio Browser client)' },
          signal: AbortSignal.timeout(8000),
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const payload = await response.json();
        if (!validate(payload)) throw new TypeError('Invalid Radio Browser response');
        return payload;
      } catch (error) {
        console.warn(`Radio Browser request to ${host} failed: ${error.message}`);
        errors.push(error);
      }
    }
    this.serversExpireAt = 0;
    throw new AggregateError(errors, 'Radio Browser is unavailable');
  }

  async _countries() {
    if (this.countries && this.countriesExpireAt > this.now()) return this.countries;
    if (!this.countriesInFlight) {
      this.countriesInFlight = this._request('/json/countrycodes?hidebroken=true', Array.isArray)
        .then((entries) => {
          const codes = [...new Set(entries.filter((entry) => typeof entry?.name === 'string' &&
            /^[A-Z]{2}$/.test(entry.name) && entry.stationcount > 0).map((entry) => entry.name))];
          this.countries = codes.map((code) => ({
            code,
            name: COUNTRY_NAMES.get('en').of(code),
            names: Object.fromEntries([...COUNTRY_NAMES].map(([language, names]) => [language, names.of(code)])),
            flag: String.fromCodePoint(...[...(code === 'UK' ? 'GB' : code)].map((letter) => letter.charCodeAt(0) + 127397)),
          })).sort((a, b) => a.name.localeCompare(b.name));
          this.countriesExpireAt = this.now() + TTL_MS;
          return this.countries;
        })
        .finally(() => { this.countriesInFlight = null; });
    }
    return this.countriesInFlight;
  }

  async getCatalogue({ country = '', query = '' } = {}) {
    if (typeof country !== 'string' || (country !== '' && !/^[A-Z]{2}$/.test(country))) {
      const error = new Error('Invalid radio country');
      error.statusCode = 400;
      error.code = 'invalid_radio_country';
      throw error;
    }
    if (typeof query !== 'string') {
      const error = new Error('Invalid radio search');
      error.statusCode = 400;
      error.code = 'invalid_radio_query';
      throw error;
    }
    const search = query.trim();
    const cacheKey = JSON.stringify([country, search.toLowerCase()]);
    const cached = this.catalogues.get(cacheKey);
    if (cached && cached.expiresAt > this.now()) return { stations: cached.stations, countries: await this._countries() };
    if (!this.inFlight.has(cacheKey)) {
      const params = new URLSearchParams({ hidebroken: 'true', order: 'clickcount', reverse: 'true', limit: '60' });
      if (country) params.set('countrycode', country);
      if (search) params.set('name', search);
      const pending = this._request(`/json/stations/search?${params}`, Array.isArray)
        .then((entries) => {
          const stations = new Map();
          for (const entry of entries) {
            const station = normalizeStation(entry);
            if (station && (!country || station.countryCode === country) && !stations.has(station.id)) stations.set(station.id, station);
          }
          const result = [...stations.values()].slice(0, 60);
          this.catalogues.delete(cacheKey);
          this.catalogues.set(cacheKey, { stations: result, expiresAt: this.now() + TTL_MS });
          if (this.catalogues.size > 32) this.catalogues.delete(this.catalogues.keys().next().value);
          return result;
        })
        .finally(() => { this.inFlight.delete(cacheKey); });
      this.inFlight.set(cacheKey, pending);
    }
    const [stations, countries] = await Promise.all([this.inFlight.get(cacheKey), this._countries()]);
    return { stations, countries };
  }

  _validateId(id) {
    if (typeof id !== 'string' || !UUID.test(id)) {
      const error = new Error('Invalid radio station ID');
      error.statusCode = 400;
      throw error;
    }
  }

  async getStation(id) {
    this._validateId(id);
    const entries = await this._request(`/json/stations/byuuid/${id}`, Array.isArray);
    return entries.filter((entry) => entry?.stationuuid === id).map(normalizeStation).find(Boolean) ?? null;
  }

  async startPlayback(id) {
    this._validateId(id);
    const result = await this._request(`/json/url/${id}`, (payload) =>
      payload?.ok === true && payload.stationuuid === id && httpUrl(payload.url) !== null);
    return { url: httpUrl(result.url) };
  }
}

module.exports = { RadioCatalog };
