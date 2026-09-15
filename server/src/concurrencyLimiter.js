// A tiny counting gate that caps how many scrapes run at once. Callers check
// `tryAcquire()` and must call `release()` in a `finally` block.
const { createLogger } = require('./logger');

const log = createLogger('limiter');

class ConcurrencyLimiter {
  constructor(maxConcurrent) {
    this.maxConcurrent = maxConcurrent;
    this.active = 0;
    log.debug('limiter created', { maxConcurrent });
  }

  get activeCount() {
    return this.active;
  }

  tryAcquire() {
    if (this.active >= this.maxConcurrent) {
      log.warn('acquire denied: at capacity', { active: this.active, max: this.maxConcurrent });
      return false;
    }
    this.active += 1;
    log.debug('slot acquired', { active: this.active, max: this.maxConcurrent });
    return true;
  }

  release() {
    if (this.active > 0) this.active -= 1;
    log.debug('slot released', { active: this.active, max: this.maxConcurrent });
  }
}

module.exports = { ConcurrencyLimiter };
