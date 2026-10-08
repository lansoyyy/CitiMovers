/**
 * Pure helpers for the completion report builder.
 *
 * Kept in a standalone module so they can be unit-tested with `node --test`
 * without touching Firestore.
 */

const PHOTO_KEYS = {
  loadingStart: ['start_loading', 'start_loading_photo'],
  loadingFinish: [
    'finish_loading',
    'finished_loading',
    'finish_loading_photo',
  ],
  unloadingStart: ['start_unloading', 'start_unloading_photo'],
  unloadingFinish: [
    'finish_unloading',
    'finished_unloading',
    'finish_unloading_photo',
  ],
  receiverId: ['receiver_id', 'receiver_id_photo'],
  receiverSignature: ['receiver_signature', 'signature'],
};

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function toMs(value) {
  if (value == null) return null;
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (typeof value.seconds === 'number') return value.seconds * 1000;
  return null;
}

/** Formats an epoch-ms instant as the report's `M/d/yyyy HH:mm` (PHT, UTC+8). */
function formatPht(ms) {
  if (ms == null) return '';
  const d = new Date(ms + 8 * 60 * 60 * 1000);
  const month = d.getUTCMonth() + 1;
  const day = d.getUTCDate();
  const year = d.getUTCFullYear();
  const hh = String(d.getUTCHours()).padStart(2, '0');
  const mi = String(d.getUTCMinutes()).padStart(2, '0');
  return `${month}/${day}/${year} ${hh}:${mi}`;
}

/** Formats the `yyyyMMdd` (PHT) day key used in the email subject. */
function formatPhtDateKey(ms) {
  if (ms == null) return '';
  const d = new Date(ms + 8 * 60 * 60 * 1000);
  const month = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${d.getUTCFullYear()}${month}${day}`;
}

/**
 * The rider app stores `receiver_signature_timestamp` as a PHT wall-clock ISO
 * string without a zone suffix (e.g. 2026-09-22T14:35:10.000). Parsing it as
 * UTC would shift the display by 8 hours, so read the components directly.
 */
function formatPhtWallClock(value) {
  if (typeof value !== 'string' || value.trim() === '') return '';
  const m = value.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/);
  if (!m) return '';
  const month = String(Number(m[2]));
  const day = String(Number(m[3]));
  return `${month}/${day}/${m[1]} ${m[4]}:${m[5]}`;
}

function photoUrl(value) {
  if (value == null) return '';
  if (typeof value === 'string') return value.trim();
  if (typeof value === 'object' && typeof value.url === 'string') {
    return value.url.trim();
  }
  return '';
}

function photoUploadedAtMs(deliveryPhotos, keys) {
  for (const key of keys) {
    const entry = deliveryPhotos[key];
    if (entry && typeof entry === 'object') {
      const ms = toMs(entry.uploadedAt ?? entry.timestamp);
      if (ms != null) return ms;
    }
  }
  return null;
}

function firstPhotoUrl(deliveryPhotos, keys) {
  for (const key of keys) {
    const url = photoUrl(deliveryPhotos[key]);
    if (url) return url;
  }
  return '';
}

function collectUrlsByPrefix(deliveryPhotos, prefixes) {
  const urls = [];
  for (const [key, value] of Object.entries(deliveryPhotos)) {
    if (!prefixes.some((prefix) => key.startsWith(prefix))) continue;
    const push = (entry) => {
      if (Array.isArray(entry)) {
        entry.forEach(push);
        return;
      }
      const url = photoUrl(entry);
      if (url && !urls.includes(url)) urls.push(url);
    };
    push(value);
  }
  return urls;
}

function normalizeEmail(value) {
  const email = (value == null ? '' : String(value)).trim();
  if (!email || !email.includes('@') || /\s/.test(email)) return null;
  return email;
}

function dedupeEmails(values) {
  const seen = new Set();
  const result = [];
  for (const value of values) {
    const email = normalizeEmail(value);
    if (!email) continue;
    const key = email.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(email);
  }
  return result;
}

function formatPicklist(value) {
  if (!Array.isArray(value)) return '';
  const lines = [];
  for (const raw of value) {
    if (!raw || typeof raw !== 'object') continue;
    const item = String(raw.item ?? '');
    const qty = String(raw.quantity ?? '');
    const desc = String(raw.description ?? '');
    if (!item && !qty) continue;
    lines.push(desc ? `${item} (${desc}) - ${qty}` : `${item} - ${qty}`);
  }
  return lines.join('\n');
}

module.exports = {
  PHOTO_KEYS,
  sleep,
  toMs,
  formatPht,
  formatPhtDateKey,
  formatPhtWallClock,
  photoUrl,
  photoUploadedAtMs,
  firstPhotoUrl,
  collectUrlsByPrefix,
  normalizeEmail,
  dedupeEmails,
  formatPicklist,
};
