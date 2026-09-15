// A tiny counting gate that caps how many scrapes run at once. Callers check
// `tryAcquire()` and must call `release()` in a `finally` block.
class ConcurrencyLimiter {
  constructor(maxConcurrent) {
    this.maxConcurrent = maxConcurrent;
    this.active = 0;
  }

  get activeCount() {
    return this.active;
  }

  tryAcquire() {
    if (this.active >= this.maxConcurrent) return false;
    this.active += 1;
    return true;
  }

  release() {
    if (this.active > 0) this.active -= 1;
  }
}

module.exports = { ConcurrencyLimiter };
