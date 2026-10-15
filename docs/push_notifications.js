(() => {
  const base = new URL('./', document.baseURI);
  const scope = new URL('push/', base).href;
  const supported = () => window.isSecureContext && 'serviceWorker' in navigator &&
    'PushManager' in window && 'Notification' in window;
  const registration = async () => {
    const reg = await navigator.serviceWorker.register(new URL('push_service_worker.js', base).href, { scope });
    if (!reg.active) {
      const worker = reg.installing || reg.waiting;
      if (!worker) throw new Error('Push service worker did not start.');
      await new Promise((resolve, reject) => {
        const changed = () => {
          if (worker.state === 'activated') {
            worker.removeEventListener('statechange', changed);
            resolve();
          } else if (worker.state === 'redundant') {
            worker.removeEventListener('statechange', changed);
            reject(new Error('Push service worker failed to activate.'));
          }
        };
        worker.addEventListener('statechange', changed);
        changed();
      });
    }
    return reg;
  };
  window.popcornPushSupported = supported;
  window.popcornPushPermission = async () => {
    if (!supported()) throw new Error('Web Push is not supported in this browser.');
    if (await Notification.requestPermission() !== 'granted') throw new Error('Notification permission was not granted.');
  };
  window.popcornPushSubscription = async () => {
    if (!supported()) return '';
    const reg = await navigator.serviceWorker.getRegistration(scope);
    const subscription = reg && reg.scope === scope && await reg.pushManager.getSubscription();
    return subscription ? JSON.stringify(subscription.toJSON()) : '';
  };
  window.popcornPushSubscribe = async (publicKey) => {
    if (!supported()) throw new Error('Web Push is not supported in this browser.');
    if (Notification.permission !== 'granted') throw new Error('Notification permission was not granted.');
    const padded = publicKey.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(publicKey.length / 4) * 4, '=');
    const key = Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
    const reg = await registration();
    const subscription = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
    return JSON.stringify(subscription.toJSON());
  };
  window.popcornPushUnsubscribe = async () => {
    const reg = await navigator.serviceWorker.getRegistration(scope);
    const subscription = reg && reg.scope === scope && await reg.pushManager.getSubscription();
    if (subscription && !await subscription.unsubscribe()) throw new Error('Could not disable browser notifications.');
  };
})();
