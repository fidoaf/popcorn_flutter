const { randomUUID } = require('node:crypto');

class SubtitleRefStore {
  constructor({ ttlMs = 5 * 60 * 1000 } = {}) {
    this.ttlMs = ttlMs;
    this.entries = new Map();
  }

  add(ref, providerId) {
    this._pruneExpired();
    const id = randomUUID();
    this.entries.set(id, { ref, providerId, expiresAt: Date.now() + this.ttlMs });
    return id;
  }

  get(id) {
    const entry = this.entries.get(id);
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