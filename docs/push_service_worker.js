self.addEventListener('push', (event) => {
  event.waitUntil((async () => {
    const message = event.data.json();
    await self.registration.showNotification(message.title, {
      body: message.body,
      icon: new URL('icons/Icon-192.png', self.location.href).href,
      data: { url: message.url },
    });
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const base = new URL('./', self.location.href);
    const target = new URL(event.notification.data.url, base);
    if (target.origin !== base.origin || !target.pathname.startsWith(base.pathname)) {
      throw new Error('Notification URL is outside the app.');
    }
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (client.url === target.href && 'focus' in client) return client.focus();
    }
    return self.clients.openWindow(target.href);
  })());
});

self.addEventListener('install', (event) => event.waitUntil(self.skipWaiting()));
