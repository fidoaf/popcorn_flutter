export function isPushEndpoint(endpoint: string): boolean {
  try {
    const url = new URL(endpoint);
    return url.protocol === "https:" && !url.username && !url.password &&
      (!url.port || url.port === "443") && (
        ["fcm.googleapis.com", "android.googleapis.com", "updates.push.services.mozilla.com", "web.push.apple.com"].includes(url.hostname) ||
        url.hostname.endsWith(".notify.windows.com")
      );
  } catch {
    return false;
  }
}

export function validateMessage(input: unknown, appUrl: string) {
  if (!input || typeof input !== "object") throw new Error("A notification object is required.");
  const { title, body, url } = input as Record<string, unknown>;
  if (typeof title !== "string" || !title.trim() || title.trim().length > 100) {
    throw new Error("Title must contain 1 to 100 characters.");
  }
  if (typeof body !== "string" || !body.trim() || body.trim().length > 1000) {
    throw new Error("Message must contain 1 to 1000 characters.");
  }
  if (url !== undefined && typeof url !== "string") throw new Error("URL must be a string.");
  const base = new URL(appUrl);
  const target = new URL(typeof url === "string" && url.trim() ? url.trim() : appUrl, base);
  if (target.origin !== base.origin || !target.pathname.startsWith(base.pathname) || target.username || target.password) {
    throw new Error("Notification URL must be inside the configured app.");
  }
  const message = { title: title.trim(), body: body.trim(), url: target.href };
  if (new TextEncoder().encode(JSON.stringify(message)).length > 3072) {
    throw new Error("Notification is too large. Shorten the message or URL.");
  }
  return message;
}
