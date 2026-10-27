const { randomUUID } = require('node:crypto');

class SourceRefStore {
  constructor({ ttlMs = 5 * 60 * 1000, tokenCodec = null } = {}) {
    this.ttlMs = ttlMs;
    this.tokenCodec = tokenCodec;
    this.entries = new Map();
  }

  add(source, providerId, media) {
    const entry = {
      ...source,
      providerId,
      mediaKey: [media.type, media.id, media.season, media.episode, media.lang, media.sub].join(':'),
      expiresAt: Date.now() + this.ttlMs,
    };
    if (this.tokenCodec) return this.tokenCodec.encode('source', entry, entry.expiresAt);
    this._pruneExpired();
    const id = randomUUID();
    this.entries.set(id, entry);
    return id;
  }

  get(id, providerId, media) {
    const entry = this.tokenCodec ? this.tokenCodec.decode(id, 'source') : this.entries.get(id);
    if (!entry) return null;
    if (entry.expiresAt <= Date.now()) {
      this.entries.delete(id);
      return null;
    }
    const mediaKey = [media.type, media.id, media.season, media.episode, media.lang, media.sub].join(':');
    if (entry.providerId !== providerId || entry.mediaKey !== mediaKey) return null;
    return entry;
  }

  _pruneExpired() {
    const now = Date.now();
    for (const [id, entry] of this.entries) {
      if (entry.expiresAt <= now) this.entries.delete(id);
    }
  }
}

module.exports = { SourceRefStore };