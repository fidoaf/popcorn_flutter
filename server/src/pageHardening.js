// Browser-side hardening applied before any page script runs: blocks pop-ups,
// `about:blank` redirects, alerts, and the `navigator.webdriver` tell-tale.
// These functions run inside the page context via `evaluateOnNewDocument`.
function blockNavigationHijacks() {
  try {
    const blocked = ['about:blank'];
    const wrap = (obj, prop) => {
      try {
        const original = obj[prop];
        if (typeof original === 'function') {
          obj[prop] = function (url) {
            if (blocked.some((b) => String(url).includes(b))) return;
            return original.call(this, url);
          };
        }
      } catch (_) {}
    };

    wrap(window.location, 'assign');
    wrap(window.location, 'replace');
    try {
      window.open = () => null;
    } catch (_) {}
    try {
      Object.defineProperty(window, 'name', { get: () => '', configurable: true });
    } catch (_) {}
    try {
      history.pushState = function () {};
      history.replaceState = function () {};
    } catch (_) {}
  } catch (_) {}
}

function maskAutomation() {
  try {
    Object.defineProperty(navigator, 'webdriver', { get: () => false });
  } catch (_) {}
  try {
    window.open = () => null;
    window.alert = () => null;
    window.confirm = () => true;
    window.prompt = () => null;
  } catch (_) {}
  try {
    const originalAssign = window.location.assign;
    window.location.assign = function (url) {
      if (String(url).includes('about:blank')) return;
      return originalAssign.call(this, url);
    };

    const originalReplace = window.location.replace;
    window.location.replace = function (url) {
      if (String(url).includes('about:blank')) return;
      return originalReplace.call(this, url);
    };
  } catch (_) {}
}

module.exports = { blockNavigationHijacks, maskAutomation };
