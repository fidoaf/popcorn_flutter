const { randomUUID } = require('node:crypto');

class SubtitleRefStore {
  constructor({ ttlMs = 5 * 60 * 1000, tokenCodec = null } = {}) {
    this.ttlMs = ttlMs;
    this.tokenCodec = tokenCodec;
    this.entries = new Map();
  }

  add(ref, providerId) {
    const entry = { ref, providerId, expiresAt: Date.now() + this.ttlMs };
    if (this.tokenCodec) return this.tokenCodec.encode('subtitle', entry, entry.expiresAt);
    this._pruneExpired();
    const id = randomUUID();
    this.entries.set(id, entry);
    return id;
  }

  get(id) {
    const entry = this.tokenCodec ? this.tokenCodec.decode(id, 'subtitle') : this.entries.get(id);
    if (!entry) return null;
    if (entry.expiresAt <= Date.now()) {
      this.entries.delete(id);
      return null;
    }
    return entry;
  }

  _pruneExpired() {
    const now = Date.now();
    for (const [id, entry] of this.entries) {
      if (entry.expiresAt <= now) this.entries.delete(id);
    }
  }
}

module.exports = { SubtitleRefStore };