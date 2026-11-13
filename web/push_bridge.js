window.dmskyShowForegroundPush = function (title, body, payloadJson) {
  if (!("serviceWorker" in navigator) || Notification.permission !== "granted") {
    return;
  }
  let payload;
  try {
    payload = JSON.parse(payloadJson);
  } catch (_) {
    return;
  }
  navigator.serviceWorker.ready.then(function (registration) {
    return registration.showNotification(title || "DMSKY Client", {
      body: body || "新しい通知があります",
      icon: "icons/Icon-192.png",
      badge: "icons/Icon-192.png",
      data: { payload: payload }
    });
  }).catch(function () {
    // A missing/blocked service worker must not break the running client.
  });
};
