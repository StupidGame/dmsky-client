/* Firebase Messaging service worker for DMSKY Client.
 * Copy web/firebase-config.js.example to web/firebase-config.js and fill the
 * public Firebase web app configuration before deploying the web build.
 */
importScripts("https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js");

// firebase-config.js is supplied at deployment time. Keep the worker installable
// in local/unconfigured builds instead of failing when the optional file is absent.
try {
  importScripts(new URL("./firebase-config.js", self.location.href).href);
} catch (_) {
  self.DMSKY_FIREBASE_CONFIG = null;
}

if (self.DMSKY_FIREBASE_CONFIG) {
  firebase.initializeApp(self.DMSKY_FIREBASE_CONFIG);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage(function (payload) {
    const data = payload.data || {};
    const notification = payload.notification || {};
    const title = notification.title || data.title || "DMSKY Client";
    const body = notification.body || data.body || "新しい通知があります";
    return self.registration.showNotification(title, {
      body: body,
      icon: "icons/Icon-192.png",
      badge: "icons/Icon-192.png",
      data: { payload: data }
    });
  });
}

self.addEventListener("notificationclick", function (event) {
  event.notification.close();
  const payload = (event.notification.data && event.notification.data.payload) || {};
  const encoded = encodeURIComponent(JSON.stringify(payload));
  const target = new URL("./?dmsky_push=" + encoded, self.location.href).toString();

  event.waitUntil(self.clients.matchAll({
    type: "window",
    includeUncontrolled: true
  }).then(async function (clients) {
    for (const client of clients) {
      if (new URL(client.url).origin !== self.location.origin) continue;
      try {
        const navigated = await client.navigate(target);
        if (navigated) return navigated.focus();
      } catch (_) {
        // Open a fresh client below if the existing page cannot be navigated.
      }
    }
    return self.clients.openWindow(target);
  }));
});
