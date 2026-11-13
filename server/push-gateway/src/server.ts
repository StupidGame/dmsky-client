import "dotenv/config";

import { lookup } from "node:dns/promises";
import { createCipheriv, createDecipheriv, randomBytes, randomUUID } from "node:crypto";
import { isIP } from "node:net";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { URL } from "node:url";

import { applicationDefault, cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging, type Message as FirebaseMessage } from "firebase-admin/messaging";
import pg from "pg";
import webpush from "web-push";
import WebSocket from "ws";
import { z } from "zod";

const { Pool } = pg;
const PORT = Number(process.env.PORT ?? "8080");
const HOST = process.env.HOST ?? "0.0.0.0";
const MAX_BODY_BYTES = 32 * 1024;
const MAX_REQUESTS_PER_MINUTE = 90;
const CHANNEL_ID = "dmsky-push-main";
const allowedOrigins = new Set(
  (process.env.CORS_ORIGINS ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
);

const requestSchema = z.object({
  schemaVersion: z.literal(1),
  deviceId: z.string().min(8).max(128),
  platform: z.enum(["android", "ios", "web", "macos", "linux"]),
  provider: z.enum(["fcm", "unifiedpush"]),
  account: z.object({
    host: z.string().min(1).max(255),
    userId: z.string().min(1).max(128),
  }),
  registration: z.record(z.string(), z.unknown()),
});

const deleteSchema = z.object({
  schemaVersion: z.literal(1),
  deviceId: z.string().min(8).max(128),
  account: z.object({
    host: z.string().min(1).max(255),
    userId: z.string().min(1).max(128),
  }),
});

type Provider = "fcm" | "unifiedpush";
type PushEventType = "notification" | "chat";
type Platform = "android" | "ios" | "web" | "macos" | "linux";
type FcmRegistration = { token: string };
type UnifiedPushRegistration = {
  endpoint: string;
  keys: { p256dh: string; auth: string };
  temporary?: boolean;
};
type Registration = FcmRegistration | UnifiedPushRegistration;
type AccountIdentity = { host: string; userId: string };
type DeviceRow = {
  device_id: string;
  host: string;
  user_id: string;
  platform: Platform;
  provider: Provider;
  registration_ciphertext: string;
};
type AccountRow = {
  host: string;
  user_id: string;
  token_ciphertext: string;
  last_notification_id: string | null;
};
type PushPayload = {
  v: "1";
  eventId: string;
  host: string;
  target: "note" | "user" | "chat" | "notifications";
  noteId?: string;
  userId?: string;
  chatId?: string;
  title: string;
  body: string;
};
type Hub = {
  key: string;
  host: string;
  userId: string;
  tokenCiphertext: string;
  lastNotificationId: string | null;
  stopped: boolean;
  retryMs: number;
  socket?: WebSocket;
  retryTimer?: NodeJS.Timeout;
  heartbeat?: NodeJS.Timeout;
  notificationChain: Promise<void>;
};

const pool = new Pool({
  connectionString: requiredEnv("DATABASE_URL"),
  ssl: process.env.DATABASE_SSL === "true" ? { rejectUnauthorized: true } : undefined,
  max: Number(process.env.DATABASE_POOL_SIZE ?? "10"),
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 10_000,
});

const requestBuckets = new Map<string, { startedAt: number; count: number }>();
const hubs = new Map<string, Hub>();
const deliveryRetryTimers = new Map<string, NodeJS.Timeout>();
const DELIVERY_RETRY_MS = 60_000;
let firebaseAdminReady = false;
let webPushReady = false;

function deliveryRetryKey(
  host: string,
  userId: string,
  eventId: string,
  eventType: PushEventType,
): string {
  return host + "|" + userId + "|" + eventType + "|" + eventId;
}

function clearDeliveryRetry(
  host: string,
  userId: string,
  eventId: string,
  eventType: PushEventType,
): void {
  const key = deliveryRetryKey(host, userId, eventId, eventType);
  const timer = deliveryRetryTimers.get(key);
  if (timer) clearTimeout(timer);
  deliveryRetryTimers.delete(key);
}

function scheduleDeliveryRetry(
  host: string,
  userId: string,
  payload: PushPayload,
  eventType: PushEventType,
): void {
  const key = deliveryRetryKey(host, userId, payload.eventId, eventType);
  if (deliveryRetryTimers.has(key)) return;
  const timer = setTimeout(() => {
    deliveryRetryTimers.delete(key);
    void dispatchToAccount(host, userId, payload, eventType).catch((error: unknown) => {
      const code = (error as { code?: string }).code ?? "unknown";
      console.error("Push retry failed", { code, host, userId });
      scheduleDeliveryRetry(host, userId, payload, eventType);
    });
  }, DELIVERY_RETRY_MS);
  timer.unref();
  deliveryRetryTimers.set(key, timer);
}

function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function encryptionKey(): Buffer {
  const key = Buffer.from(requiredEnv("PUSH_TOKEN_ENCRYPTION_KEY"), "hex");
  if (key.length !== 32) {
    throw new Error("PUSH_TOKEN_ENCRYPTION_KEY must be exactly 32 bytes (64 hex characters)");
  }
  return key;
}

function encryptToken(token: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", encryptionKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(token, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [iv, tag, ciphertext].map((value) => value.toString("base64url")).join(".");
}

function decryptToken(value: string): string {
  const [ivText, tagText, ciphertextText] = value.split(".");
  if (!ivText || !tagText || !ciphertextText) throw new Error("Stored token ciphertext is malformed");
  const decipher = createDecipheriv(
    "aes-256-gcm",
    encryptionKey(),
    Buffer.from(ivText, "base64url"),
  );
  decipher.setAuthTag(Buffer.from(tagText, "base64url"));
  return Buffer.concat([
    decipher.update(Buffer.from(ciphertextText, "base64url")),
    decipher.final(),
  ]).toString("utf8");
}

function isPublicIp(address: string): boolean {
  const version = isIP(address);
  if (version === 4) {
    const parts = address.split(".").map(Number);
    const [a, b] = parts;
    if (a === undefined || b === undefined) return false;
    if (a === 0 || a === 10 || a === 127 || a >= 224) return false;
    if (a === 100 && b >= 64 && b <= 127) return false;
    if (a === 169 && b === 254) return false;
    if (a === 172 && b >= 16 && b <= 31) return false;
    if (a === 192 && (b === 0 || b === 168)) return false;
    if (a === 198 && (b === 18 || b === 19)) return false;
    if (a === 203 && b === 0) return false;
    return true;
  }
  if (version === 6) {
    const value = address.toLowerCase();
    if (value === "::" || value === "::1" || value.startsWith("fc") ||
        value.startsWith("fd") || value.startsWith("fe8") ||
        value.startsWith("fe9") || value.startsWith("fea") ||
        value.startsWith("feb") || value.startsWith("::ffff:") ||
        value.startsWith("2001:db8:")) return false;
    return true;
  }
  return false;
}

async function assertPublicHost(hostname: string): Promise<void> {
  const normalized = hostname.toLowerCase().replace(/\.$/, "");
  if (!normalized || normalized === "localhost" || normalized.endsWith(".localhost") ||
      normalized.endsWith(".local") || normalized.endsWith(".internal")) {
    throw new Error("Private or local hostnames are not permitted");
  }
  if (isIP(normalized)) {
    if (!isPublicIp(normalized)) throw new Error("Private IP addresses are not permitted");
    return;
  }
  const addresses = await lookup(normalized, { all: true, verbatim: true });
  if (addresses.length === 0 || addresses.some((entry) => !isPublicIp(entry.address))) {
    throw new Error("Host does not resolve exclusively to public IP addresses");
  }
}

async function normalizeMisskeyHost(input: string): Promise<{ host: string; origin: string }> {
  const value = input.includes("://") ? input : "https://" + input;
  const uri = new URL(value);
  if (uri.protocol !== "https:" || !uri.hostname || uri.username || uri.password ||
      (uri.pathname !== "/" && uri.pathname !== "") || uri.search || uri.hash) {
    throw new Error("Misskey host must be a plain HTTPS origin without credentials or a path");
  }
  await assertPublicHost(uri.hostname);
  const host = uri.port ? uri.hostname.toLowerCase() + ":" + uri.port : uri.hostname.toLowerCase();
  return { host, origin: uri.origin };
}

async function validatePushEndpoint(input: string): Promise<string> {
  const uri = new URL(input);
  if (uri.protocol !== "https:" || !uri.hostname || uri.username || uri.password ||
      uri.hash || uri.hostname.toLowerCase() === "localhost") {
    throw new Error("UnifiedPush endpoint must be a public HTTPS URL");
  }
  await assertPublicHost(uri.hostname);
  return uri.toString();
}

async function verifyMisskeyToken(
  origin: string,
  token: string,
  expectedUserId: string,
): Promise<void> {
  const response = await fetch(new URL("/api/i", origin), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ i: token }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) throw new Error("Misskey authentication check failed");
  const identity = await response.json() as { id?: unknown };
  if (identity.id !== expectedUserId) {
    throw new Error("Misskey token does not belong to the requested account");
  }
}

function accountKey(host: string, userId: string): string {
  return host + "|" + userId;
}

function parseRegistration(provider: Provider, raw: Record<string, unknown>): Registration {
  if (provider === "fcm") {
    const token = raw.token;
    if (typeof token !== "string" || token.length < 20 || token.length > 8192) {
      throw new Error("FCM registration token is invalid");
    }
    return { token };
  }
  const endpoint = raw.endpoint;
  const keys = raw.keys;
  if (typeof endpoint !== "string" || typeof keys !== "object" || keys === null ||
      typeof (keys as Record<string, unknown>).p256dh !== "string" ||
      typeof (keys as Record<string, unknown>).auth !== "string") {
    throw new Error("UnifiedPush registration must include endpoint, p256dh and auth");
  }
  const p256dh = (keys as Record<string, unknown>).p256dh as string;
  const auth = (keys as Record<string, unknown>).auth as string;
  if (p256dh.length > 512 || auth.length > 256 || p256dh.length < 16 || auth.length < 8) {
    throw new Error("UnifiedPush encryption keys are invalid");
  }
  return { endpoint, keys: { p256dh, auth }, temporary: raw.temporary === true };
}

async function initializeFirebase(): Promise<void> {
  if (getApps().length > 0) {
    firebaseAdminReady = true;
    return;
  }
  try {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const credential = raw?.trim()
      ? cert(JSON.parse(raw))
      : applicationDefault();
    // Resolve credentials during startup so a missing service account cannot
    // appear healthy and fail only after the first notification arrives.
    await credential.getAccessToken();
    initializeApp({ credential });
    firebaseAdminReady = true;
  } catch (error) {
    firebaseAdminReady = false;
    const code = (error as { code?: string }).code ?? "unknown";
    console.error("Firebase Admin is not configured; FCM delivery is disabled", { code });
  }
}

function configureWebPush(): void {
  const subject = process.env.VAPID_SUBJECT?.trim();
  const publicKey = process.env.VAPID_PUBLIC_KEY?.trim();
  const privateKey = process.env.VAPID_PRIVATE_KEY?.trim();
  if (!subject || !publicKey || !privateKey) {
    webPushReady = false;
    console.warn("Web Push VAPID keys are not configured; UnifiedPush delivery is disabled");
    return;
  }
  try {
    webpush.setVapidDetails(subject, publicKey, privateKey);
    webPushReady = true;
  } catch (error) {
    webPushReady = false;
    const code = (error as { code?: string }).code ?? "unknown";
    console.error("Web Push VAPID configuration is invalid", { code });
  }
}

async function ensureSchema(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS push_accounts (
      host TEXT NOT NULL,
      user_id TEXT NOT NULL,
      token_ciphertext TEXT NOT NULL,
      last_notification_id TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (host, user_id)
    );
    CREATE TABLE IF NOT EXISTS push_devices (
      device_id TEXT NOT NULL,
      host TEXT NOT NULL,
      user_id TEXT NOT NULL,
      platform TEXT NOT NULL,
      provider TEXT NOT NULL CHECK (provider IN ('fcm', 'unifiedpush')),
      registration JSONB,
      registration_ciphertext TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (device_id, host, user_id, provider),
      FOREIGN KEY (host, user_id) REFERENCES push_accounts(host, user_id) ON DELETE CASCADE
    );
    ALTER TABLE push_accounts
      ADD COLUMN IF NOT EXISTS last_notification_id TEXT;
    ALTER TABLE push_devices
      ADD COLUMN IF NOT EXISTS registration_ciphertext TEXT;
    ALTER TABLE push_devices
      ALTER COLUMN registration DROP NOT NULL;
    CREATE TABLE IF NOT EXISTS push_events (
      host TEXT NOT NULL,
      user_id TEXT NOT NULL,
      event_id TEXT NOT NULL,
      event_type TEXT NOT NULL DEFAULT 'notification' CHECK (event_type IN ('notification', 'chat')),
      status TEXT NOT NULL CHECK (status IN ('pending', 'delivered')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (host, user_id, event_id),
      FOREIGN KEY (host, user_id) REFERENCES push_accounts(host, user_id) ON DELETE CASCADE
    );
    ALTER TABLE push_events
      ADD COLUMN IF NOT EXISTS event_type TEXT NOT NULL DEFAULT 'notification';
    CREATE TABLE IF NOT EXISTS push_event_deliveries (
      host TEXT NOT NULL,
      user_id TEXT NOT NULL,
      event_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      provider TEXT NOT NULL CHECK (provider IN ('fcm', 'unifiedpush')),
      status TEXT NOT NULL CHECK (status IN ('pending', 'delivered')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (host, user_id, event_id, device_id, provider),
      FOREIGN KEY (host, user_id, event_id)
        REFERENCES push_events(host, user_id, event_id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS push_devices_account_idx
      ON push_devices(host, user_id);
    CREATE INDEX IF NOT EXISTS push_events_created_idx
      ON push_events(created_at);
    CREATE INDEX IF NOT EXISTS push_event_deliveries_pending_idx
      ON push_event_deliveries(host, user_id, event_id, status);
  `);

  // Encrypt any legacy plaintext FCM tokens or UnifiedPush endpoint capabilities.
  const legacyRegistrations = await pool.query<{
    device_id: string;
    host: string;
    user_id: string;
    provider: Provider;
    registration: Registration;
  }>(
    `SELECT device_id, host, user_id, provider, registration
     FROM push_devices
     WHERE registration_ciphertext IS NULL AND registration IS NOT NULL`,
  );
  for (const row of legacyRegistrations.rows) {
    await pool.query(
      `UPDATE push_devices
       SET registration_ciphertext=$5, registration=NULL, updated_at=NOW()
       WHERE device_id=$1 AND host=$2 AND user_id=$3 AND provider=$4`,
      [
        row.device_id,
        row.host,
        row.user_id,
        row.provider,
        encryptToken(JSON.stringify(row.registration)),
      ],
    );
  }
  await pool.query(
    `ALTER TABLE push_devices
     ALTER COLUMN registration_ciphertext SET NOT NULL`,
  );
  // Bound storage growth while retaining enough history for reconnect recovery.
  await pool.query(
    "DELETE FROM push_events WHERE created_at < NOW() - INTERVAL '30 days'",
  );
}

async function storeRegistration(args: {
  deviceId: string;
  host: string;
  userId: string;
  platform: Platform;
  provider: Provider;
  registration: Registration;
  token: string;
}): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      `INSERT INTO push_accounts(host, user_id, token_ciphertext)
       VALUES ($1, $2, $3)
       ON CONFLICT(host, user_id) DO UPDATE
       SET token_ciphertext = EXCLUDED.token_ciphertext, updated_at = NOW()`,
      [args.host, args.userId, encryptToken(args.token)],
    );
    await client.query(
      `INSERT INTO push_devices(
         device_id, host, user_id, platform, provider, registration_ciphertext
       )
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT(device_id, host, user_id, provider) DO UPDATE
       SET platform = EXCLUDED.platform,
           registration_ciphertext = EXCLUDED.registration_ciphertext,
           registration = NULL,
           updated_at = NOW()`,
      [
        args.deviceId,
        args.host,
        args.userId,
        args.platform,
        args.provider,
        encryptToken(JSON.stringify(args.registration)),
      ],
    );
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function removeExpiredDevice(device: DeviceRow): Promise<void> {
  await pool.query(
    "DELETE FROM push_devices WHERE device_id=$1 AND host=$2 AND user_id=$3 AND provider=$4",
    [device.device_id, device.host, device.user_id, device.provider],
  );
  const remaining = await pool.query(
    "SELECT 1 FROM push_devices WHERE host=$1 AND user_id=$2 LIMIT 1",
    [device.host, device.user_id],
  );
  if (remaining.rowCount === 0) {
    await pool.query("DELETE FROM push_accounts WHERE host=$1 AND user_id=$2", [
      device.host,
      device.user_id,
    ]);
  }
  await refreshHub(device.host, device.user_id);
}

async function sendToDevice(device: DeviceRow, payload: PushPayload): Promise<void> {
  const registration = JSON.parse(
    decryptToken(device.registration_ciphertext),
  ) as Registration;

  if (device.provider === "fcm") {
    if (!firebaseAdminReady) {
      throw new Error("Firebase Admin credentials are not configured");
    }
    const fcmRegistration = registration as FcmRegistration;
    const message: FirebaseMessage = {
      token: fcmRegistration.token,
      // Android uses data-only FCM so both FCM and UnifiedPush go through the
      // same local notification ID and cannot create two visible alerts.
      data: Object.fromEntries(
        Object.entries(payload)
          .filter((entry): entry is [string, string] => typeof entry[1] === "string"),
      ),
      android: {
        priority: "high",
        ttl: 60 * 60 * 1000,
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: { title: payload.title, body: payload.body },
            sound: "default",
          },
        },
      },
      webpush: {
        headers: { Urgency: "high", TTL: "3600" },
        notification: { title: payload.title, body: payload.body },
      },
    };
    try {
      await getMessaging().send(message);
    } catch (error) {
      const code = (error as { code?: string }).code;
      if (code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token") {
        await removeExpiredDevice(device);
        return;
      }
      throw error;
    }
    return;
  }

  if (!webPushReady) {
    throw new Error("Web Push VAPID keys are not configured");
  }
  const unifiedRegistration = registration as UnifiedPushRegistration;
  const subscription = {
    endpoint: unifiedRegistration.endpoint,
    keys: unifiedRegistration.keys,
  };
  try {
    await webpush.sendNotification(subscription, JSON.stringify(payload), { TTL: 3600 });
  } catch (error) {
    const statusCode = (error as { statusCode?: number }).statusCode;
    if (statusCode === 404 || statusCode === 410) {
      await removeExpiredDevice(device);
      return;
    }
    throw error;
  }
}

async function claimDeviceDelivery(
  host: string,
  userId: string,
  eventId: string,
  device: DeviceRow,
): Promise<boolean> {
  const result = await pool.query(
    `INSERT INTO push_event_deliveries(
       host, user_id, event_id, device_id, provider, status
     )
     VALUES ($1, $2, $3, $4, $5, 'pending')
     ON CONFLICT(host, user_id, event_id, device_id, provider) DO UPDATE
     SET updated_at = NOW()
     WHERE push_event_deliveries.status = 'pending'
       AND push_event_deliveries.updated_at < NOW() - INTERVAL '60 seconds'
     RETURNING event_id`,
    [host, userId, eventId, device.device_id, device.provider],
  );
  return result.rowCount === 1;
}

async function dispatchToAccount(
  host: string,
  userId: string,
  payload: PushPayload,
  eventType: PushEventType = "notification",
): Promise<boolean> {
  const devices = await pool.query<DeviceRow>(
    "SELECT device_id, host, user_id, platform, provider, registration_ciphertext FROM push_devices WHERE host=$1 AND user_id=$2",
    [host, userId],
  );
  if (devices.rows.length === 0) {
    clearDeliveryRetry(host, userId, payload.eventId, eventType);
    return false;
  }

  await pool.query(
    `INSERT INTO push_events(host, user_id, event_id, event_type, status)
     VALUES ($1, $2, $3, $4, 'pending')
     ON CONFLICT(host, user_id, event_id) DO NOTHING`,
    [host, userId, payload.eventId, eventType],
  );
  const event = await pool.query<{ status: "pending" | "delivered" }>(
    "SELECT status FROM push_events WHERE host=$1 AND user_id=$2 AND event_id=$3",
    [host, userId, payload.eventId],
  );
  if (event.rows[0]?.status === "delivered") {
    clearDeliveryRetry(host, userId, payload.eventId, eventType);
    return true;
  }

  await Promise.all(devices.rows.map(async (device) => {
    const claimed = await claimDeviceDelivery(host, userId, payload.eventId, device);
    if (!claimed) return;
    try {
      await sendToDevice(device, payload);
      await pool.query(
        `UPDATE push_event_deliveries
         SET status='delivered', updated_at=NOW()
         WHERE host=$1 AND user_id=$2 AND event_id=$3
           AND device_id=$4 AND provider=$5`,
        [host, userId, payload.eventId, device.device_id, device.provider],
      );
    } catch (error) {
      await pool.query(
        `UPDATE push_event_deliveries
         SET updated_at=NOW()
         WHERE host=$1 AND user_id=$2 AND event_id=$3
           AND device_id=$4 AND provider=$5 AND status='pending'`,
        [host, userId, payload.eventId, device.device_id, device.provider],
      );
      const code = (error as { code?: string }).code ?? "unknown";
      console.error("Push delivery failed", {
        code,
        host,
        userId,
        provider: device.provider,
      });
    }
  }));

  const pending = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count
     FROM push_event_deliveries d
     INNER JOIN push_devices p
       ON p.host=d.host AND p.user_id=d.user_id
       AND p.device_id=d.device_id AND p.provider=d.provider
     WHERE d.host=$1 AND d.user_id=$2 AND d.event_id=$3
       AND d.status <> 'delivered'`,
    [host, userId, payload.eventId],
  );
  const delivered = Number(pending.rows[0]?.count ?? "0") === 0;
  await pool.query(
    "UPDATE push_events SET status=$4, updated_at=NOW() WHERE host=$1 AND user_id=$2 AND event_id=$3",
    [host, userId, payload.eventId, delivered ? "delivered" : "pending"],
  );
  if (delivered) {
    clearDeliveryRetry(host, userId, payload.eventId, eventType);
  } else {
    scheduleDeliveryRetry(host, userId, payload, eventType);
  }
  return delivered;
}

async function updateNotificationCursor(
  hub: Hub,
  notificationId: string,
): Promise<void> {
  // Do not move the recovery cursor past an event that is still waiting for
  // one or more devices. A later live event must not hide an earlier failure.
  const pending = await pool.query(
    `SELECT 1
     FROM push_events e
     WHERE e.host=$1 AND e.user_id=$2
       AND e.event_type='notification' AND e.status='pending'
       AND EXISTS (
         SELECT 1
         FROM push_event_deliveries d
         INNER JOIN push_devices p
           ON p.host=d.host AND p.user_id=d.user_id
           AND p.device_id=d.device_id AND p.provider=d.provider
         WHERE d.host=e.host AND d.user_id=e.user_id
           AND d.event_id=e.event_id AND d.status='pending'
       )
     LIMIT 1`,
    [hub.host, hub.userId],
  );
  if (pending.rows.length > 0) return;

  hub.lastNotificationId = notificationId;
  await pool.query(
    "UPDATE push_accounts SET last_notification_id=$3, updated_at=NOW() WHERE host=$1 AND user_id=$2",
    [hub.host, hub.userId, notificationId],
  );
}

async function fetchNotificationsSince(
  hub: Hub,
  token: string,
  sinceId?: string,
): Promise<Array<Record<string, unknown>>> {
  const response = await fetch(new URL("/api/i/notifications", "https://" + hub.host), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      i: token,
      limit: 100,
      markAsRead: false,
      ...(sinceId ? { sinceId } : {}),
    }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error("Misskey notification history request failed");
  const data: unknown = await response.json();
  if (!Array.isArray(data)) throw new Error("Misskey notification history response was not an array");
  return data.filter(
    (item): item is Record<string, unknown> =>
      typeof item === "object" && item !== null && !Array.isArray(item),
  );
}

async function syncNotificationHistory(hub: Hub): Promise<void> {
  if (hub.stopped || hubs.get(hub.key) !== hub) return;
  const token = decryptToken(hub.tokenCiphertext);

  // The first connection establishes a starting point instead of replaying the
  // entire pre-existing notification history to a newly enabled device.
  if (!hub.lastNotificationId) {
    const latest = await fetchNotificationsSince(hub, token);
    const newest = [...latest].sort((a, b) =>
      Date.parse(String(b.createdAt ?? 0)) - Date.parse(String(a.createdAt ?? 0)),
    )[0];
    if (typeof newest?.id === "string") {
      await updateNotificationCursor(hub, newest.id);
    }
    return;
  }

  let cursor = hub.lastNotificationId;
  for (let page = 0; page < 10; page++) {
    if (hub.stopped || hubs.get(hub.key) !== hub) return;
    const batch = await fetchNotificationsSince(hub, token, cursor);
    if (batch.length === 0) return;

    const ordered = [...batch].sort((a, b) =>
      Date.parse(String(a.createdAt ?? 0)) - Date.parse(String(b.createdAt ?? 0)),
    );
    for (const notification of ordered) {
      if (hub.stopped || hubs.get(hub.key) !== hub) return;
      const payload = notificationPayload(hub.host, notification);
      const delivered = await dispatchToAccount(hub.host, hub.userId, payload);
      if (!delivered) {
        // Keep the cursor before this item so the next reconnect can retry it.
        return;
      }
    }

    const newest = ordered[ordered.length - 1];
    if (typeof newest?.id !== "string" || newest.id === cursor) return;
    cursor = newest.id;
    await updateNotificationCursor(hub, cursor);
    if (batch.length < 100) return;
  }
}

function enqueueNotificationWork(
  hub: Hub,
  work: () => Promise<void>,
): void {
  hub.notificationChain = hub.notificationChain
    .then(work)
    .catch((error: unknown) => {
      const code = (error as { code?: string }).code ?? "unknown";
      console.error("Misskey notification synchronization failed", {
        code,
        host: hub.host,
        userId: hub.userId,
      });
    });
}


function notificationPayload(
  host: string,
  notification: Record<string, unknown>,
): PushPayload {
  const note = notification.note as { id?: unknown } | undefined;
  const user = notification.user as { id?: unknown } | undefined;
  const eventId = typeof notification.id === "string" ? notification.id : randomUUID();
  const payload: PushPayload = {
    v: "1",
    eventId,
    host,
    target: "notifications",
    title: "DMSKY Client",
    body: "新しい通知があります",
  };
  if (typeof note?.id === "string") {
    payload.target = "note";
    payload.noteId = note.id;
  } else if (typeof user?.id === "string") {
    payload.target = "user";
    payload.userId = user.id;
  }
  return payload;
}

function chatPayload(
  host: string,
  accountUserId: string,
  message: Record<string, unknown>,
): PushPayload | null {
  const senderId = typeof message.fromUserId === "string"
    ? message.fromUserId
    : typeof message.userId === "string"
    ? message.userId
    : null;
  // Never send a push back to the account for its own outgoing message.
  if (senderId === accountUserId) return null;

  const room = message.toRoom as { id?: unknown } | undefined;
  const roomId = typeof message.toRoomId === "string"
    ? message.toRoomId
    : typeof room?.id === "string"
    ? room.id
    : typeof message.roomId === "string"
    ? message.roomId
    : typeof message.groupId === "string"
    ? message.groupId
    : null;
  const payload: PushPayload = {
    v: "1",
    eventId: typeof message.id === "string" ? message.id : randomUUID(),
    host,
    target: "chat",
    title: "DMSKY Client",
    body: "新しいメッセージがあります",
  };
  if (roomId) {
    payload.chatId = "room:" + roomId;
    return payload;
  }

  const recipientId = typeof message.toUserId === "string"
    ? message.toUserId
    : typeof message.recipientId === "string"
    ? message.recipientId
    : typeof (message.toUser as { id?: unknown } | undefined)?.id === "string"
    ? (message.toUser as { id: string }).id
    : null;
  const peerId = senderId && senderId !== accountUserId ? senderId : recipientId;
  if (!peerId || peerId === accountUserId) return null;
  payload.chatId = "user:" + peerId;
  return payload;
}

function stopHub(hub: Hub): void {
  hub.stopped = true;
  if (hub.retryTimer) clearTimeout(hub.retryTimer);
  if (hub.heartbeat) clearInterval(hub.heartbeat);
  try {
    hub.socket?.close();
  } catch {
    // The socket may already be closed.
  }
  if (hubs.get(hub.key) === hub) hubs.delete(hub.key);
}

function scheduleReconnect(hub: Hub): void {
  if (hub.stopped || hub.retryTimer || hubs.get(hub.key) !== hub) return;
  const wait = hub.retryMs;
  hub.retryMs = Math.min(hub.retryMs * 2, 60_000);
  hub.retryTimer = setTimeout(() => {
    hub.retryTimer = undefined;
    connectHub(hub);
  }, wait);
}

function connectHub(hub: Hub): void {
  if (hub.stopped || hubs.get(hub.key) !== hub) return;
  try {
    const token = decryptToken(hub.tokenCiphertext);
    const url = new URL("/streaming", "https://" + hub.host);
    url.protocol = "wss:";
    url.searchParams.set("i", token);
    const socket = new WebSocket(url.toString(), {
      handshakeTimeout: 10_000,
      maxPayload: 1024 * 1024,
    });
    hub.socket = socket;

    socket.on("open", () => {
      hub.retryMs = 1_000;
      const channelId = randomUUID();
      socket.send(JSON.stringify({
        type: "connect",
        body: { channel: "main", id: channelId },
      }));
      hub.heartbeat = setInterval(() => {
        if (socket.readyState === WebSocket.OPEN) socket.ping();
      }, 30_000);
      (socket as WebSocket & { dmskyChannelId?: string }).dmskyChannelId = channelId;
      // Queue recovery before live events to serialize the persisted cursor.
      enqueueNotificationWork(hub, () => syncNotificationHistory(hub));
    });

    socket.on("message", (data) => {
      try {
        const event = JSON.parse(data.toString()) as {
          type?: string;
          body?: { id?: string; type?: string; body?: Record<string, unknown> };
        };
        if (event.type !== "channel" || !event.body ||
            event.body.id !== (socket as WebSocket & { dmskyChannelId?: string }).dmskyChannelId ||
            !event.body.body) return;

        const eventType = event.body.type;
        if (eventType === "notification") {
          const notification = event.body.body;
          enqueueNotificationWork(hub, async () => {
            const payload = notificationPayload(hub.host, notification);
            const delivered = await dispatchToAccount(hub.host, hub.userId, payload);
            if (delivered && typeof notification.id === "string") {
              await updateNotificationCursor(hub, notification.id);
            }
          });
        } else if (eventType === "messagingMessage") {
          const message = event.body.body;
          enqueueNotificationWork(hub, async () => {
            const payload = chatPayload(hub.host, hub.userId, message);
            if (payload) await dispatchToAccount(hub.host, hub.userId, payload, "chat");
          });
        }
      } catch {
        // Malformed or unsupported stream events are ignored.
      }
    });

    socket.on("close", () => {
      if (hub.heartbeat) clearInterval(hub.heartbeat);
      hub.heartbeat = undefined;
      scheduleReconnect(hub);
    });
    socket.on("error", () => {
      try { socket.close(); } catch { /* ignore */ }
    });
  } catch {
    scheduleReconnect(hub);
  }
}

async function refreshHub(host: string, userId: string): Promise<void> {
  const key = accountKey(host, userId);
  const account = await pool.query<AccountRow>(
`SELECT a.host, a.user_id, a.token_ciphertext, a.last_notification_id
     FROM push_accounts a
     WHERE a.host=$1 AND a.user_id=$2
       AND EXISTS (SELECT 1 FROM push_devices d WHERE d.host=a.host AND d.user_id=a.user_id)`,
    [host, userId],
  );
  if (account.rowCount === 0) {
    const existing = hubs.get(key);
    if (existing) stopHub(existing);
    return;
  }
  const row = account.rows[0]!;
  const existing = hubs.get(key);
  if (existing && existing.tokenCiphertext === row.token_ciphertext && !existing.stopped) {
    return;
  }
  if (existing) stopHub(existing);
  const hub: Hub = {
    key,
    host: row.host,
    userId: row.user_id,
    tokenCiphertext: row.token_ciphertext,
    lastNotificationId: row.last_notification_id,
    notificationChain: Promise.resolve(),
    stopped: false,
    retryMs: 1_000,
  };
  hubs.set(key, hub);
  connectHub(hub);
}

async function refreshAllHubs(): Promise<void> {
  const result = await pool.query<AccountRow>(
    `SELECT a.host, a.user_id, a.token_ciphertext
     FROM push_accounts a
     WHERE EXISTS (SELECT 1 FROM push_devices d WHERE d.host=a.host AND d.user_id=a.user_id)`,
  );
  for (const account of result.rows) {
    await refreshHub(account.host, account.user_id);
  }
}

function rateLimitKey(request: IncomingMessage): string {
  return request.socket.remoteAddress ?? "unknown";
}

function checkRateLimit(request: IncomingMessage): boolean {
  const key = rateLimitKey(request);
  const now = Date.now();
  const current = requestBuckets.get(key);
  if (!current || now - current.startedAt >= 60_000) {
    requestBuckets.set(key, { startedAt: now, count: 1 });
    return true;
  }
  current.count++;
  return current.count <= MAX_REQUESTS_PER_MINUTE;
}

function setCors(request: IncomingMessage, response: ServerResponse): boolean {
  const origin = request.headers.origin;
  if (!origin) return true;
  if (allowedOrigins.has("*")) {
    response.setHeader("Access-Control-Allow-Origin", "*");
  } else if (allowedOrigins.has(origin)) {
    response.setHeader("Access-Control-Allow-Origin", origin);
    response.setHeader("Vary", "Origin");
  } else {
    return false;
  }
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,DELETE,OPTIONS");
  response.setHeader("Access-Control-Allow-Headers", "Authorization,Content-Type");
  response.setHeader("Access-Control-Max-Age", "600");
  return true;
}

function sendJson(response: ServerResponse, status: number, data: Record<string, unknown>): void {
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  response.end(JSON.stringify(data));
}

async function readJson(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.length;
    if (size > MAX_BODY_BYTES) throw new Error("Request body too large");
    chunks.push(buffer);
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function bearerToken(request: IncomingMessage): string {
  const value = request.headers.authorization;
  if (!value?.startsWith("Bearer ")) throw new Error("Missing bearer token");
  const token = value.slice("Bearer ".length).trim();
  if (!token || token.length > 4096) throw new Error("Invalid bearer token");
  return token;
}

async function handleRegister(request: IncomingMessage, response: ServerResponse): Promise<void> {
  const body = requestSchema.parse(await readJson(request));
  const token = bearerToken(request);
  const normalized = await normalizeMisskeyHost(body.account.host);
  if (body.provider === "fcm" && !firebaseAdminReady) {
    throw new Error("Firebase Admin credentials are not configured");
  }
  if (body.provider === "unifiedpush" && !webPushReady) {
    throw new Error("Web Push VAPID keys are not configured");
  }
  const registration = parseRegistration(body.provider, body.registration);
  if (body.provider === "unifiedpush") {
    const endpoint = await validatePushEndpoint((registration as UnifiedPushRegistration).endpoint);
    (registration as UnifiedPushRegistration).endpoint = endpoint;
  }
  await verifyMisskeyToken(normalized.origin, token, body.account.userId);
  await storeRegistration({
    deviceId: body.deviceId,
    host: normalized.host,
    userId: body.account.userId,
    platform: body.platform,
    provider: body.provider,
    registration,
    token,
  });
  await refreshHub(normalized.host, body.account.userId);
  sendJson(response, 200, { ok: true });
}

async function handleUnregister(request: IncomingMessage, response: ServerResponse): Promise<void> {
  const body = deleteSchema.parse(await readJson(request));
  const token = bearerToken(request);
  const normalized = await normalizeMisskeyHost(body.account.host);
  await verifyMisskeyToken(normalized.origin, token, body.account.userId);
  await pool.query(
    "DELETE FROM push_devices WHERE device_id=$1 AND host=$2 AND user_id=$3",
    [body.deviceId, normalized.host, body.account.userId],
  );
  const remaining = await pool.query(
    "SELECT 1 FROM push_devices WHERE host=$1 AND user_id=$2 LIMIT 1",
    [normalized.host, body.account.userId],
  );
  if (remaining.rowCount === 0) {
    await pool.query("DELETE FROM push_accounts WHERE host=$1 AND user_id=$2", [
      normalized.host,
      body.account.userId,
    ]);
  }
  await refreshHub(normalized.host, body.account.userId);
  sendJson(response, 200, { ok: true });
}

async function handleRequest(request: IncomingMessage, response: ServerResponse): Promise<void> {
  if (!setCors(request, response)) {
    sendJson(response, 403, { error: "Origin not allowed" });
    return;
  }
  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    return;
  }
  if (!checkRateLimit(request)) {
    sendJson(response, 429, { error: "Too many requests" });
    return;
  }

  const url = new URL(request.url ?? "/", "http://gateway.local");
  if (request.method === "GET" && url.pathname === "/health") {
    await pool.query("SELECT 1");
    sendJson(response, 200, { ok: true });
    return;
  }
  if (url.pathname !== "/v1/device-registrations") {
    sendJson(response, 404, { error: "Not found" });
    return;
  }

  try {
    if (request.method === "POST") {
      await handleRegister(request, response);
    } else if (request.method === "DELETE") {
      await handleUnregister(request, response);
    } else {
      sendJson(response, 405, { error: "Method not allowed" });
    }
  } catch (error) {
    const message = error instanceof z.ZodError
      ? "Invalid request payload"
      : error instanceof Error
      ? error.message
      : "Request failed";
    const status = message.includes("authentication") || message.includes("token") ? 401
      : message.includes("too large") ? 413
      : message.includes("not permitted") || message.includes("HTTPS") ? 400
      : 400;
    // Never log bearer tokens, endpoint capabilities, notification payloads or ciphertext.
    console.error("Push gateway request rejected", { status, message });
    sendJson(response, status, { error: message });
  }
}

async function shutdown(signal: string, server: ReturnType<typeof createServer>): Promise<void> {
  console.info("Shutting down push gateway", { signal });
  for (const hub of hubs.values()) stopHub(hub);
  for (const timer of deliveryRetryTimers.values()) clearTimeout(timer);
  deliveryRetryTimers.clear();
  server.close();
  await pool.end();
  process.exit(0);
}

async function main(): Promise<void> {
  encryptionKey();
  await initializeFirebase();
  configureWebPush();
  await ensureSchema();
  await refreshAllHubs();

  const server = createServer((request, response) => {
    void handleRequest(request, response).catch(() => {
      if (!response.headersSent) sendJson(response, 500, { error: "Internal server error" });
      else response.destroy();
    });
  });
  server.listen(PORT, HOST, () => {
    console.info("DMSKY push gateway listening", { host: HOST, port: PORT });
  });
  process.on("SIGTERM", () => void shutdown("SIGTERM", server));
  process.on("SIGINT", () => void shutdown("SIGINT", server));
}

void main().catch((error) => {
  console.error("Push gateway startup failed", {
    message: error instanceof Error ? error.message : "unknown error",
  });
  process.exit(1);
});
