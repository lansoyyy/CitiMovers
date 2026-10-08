/**
 * Unit tests for the report builder helpers.
 *
 * Run from the functions folder:  node --test
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  PHOTO_KEYS,
  toMs,
  formatPht,
  formatPhtDateKey,
  formatPhtWallClock,
  photoUrl,
  photoUploadedAtMs,
  firstPhotoUrl,
  collectUrlsByPrefix,
  dedupeEmails,
  formatPicklist,
} = require('./report_helpers');

test('formatPht converts UTC to Philippine time (UTC+8)', () => {
  assert.equal(formatPht(Date.UTC(1970, 0, 1, 0, 0)), '1/1/1970 08:00');
  assert.equal(
    formatPht(Date.UTC(2026, 8, 22, 6, 35)),
    '9/22/2026 14:35',
  );
  assert.equal(formatPht(null), '');
});

test('formatPhtDateKey builds the yyyyMMdd subject key in PHT', () => {
  // 2026-09-21 20:00 UTC == 2026-09-22 04:00 PHT
  assert.equal(formatPhtDateKey(Date.UTC(2026, 8, 21, 20, 0)), '20260922');
  assert.equal(formatPhtDateKey(null), '');
});

test('formatPhtWallClock reads zone-less PHT ISO strings verbatim', () => {
  assert.equal(
    formatPhtWallClock('2026-09-22T14:35:10.000'),
    '9/22/2026 14:35',
  );
  assert.equal(formatPhtWallClock('2026-01-05T08:02:00.000'), '1/5/2026 08:02');
  assert.equal(formatPhtWallClock('not-a-date'), '');
  assert.equal(formatPhtWallClock(null), '');
});

test('toMs handles numbers, ISO strings, Timestamps and serialized forms', () => {
  assert.equal(toMs(1700000000000), 1700000000000);
  assert.equal(toMs('1970-01-01T00:00:01Z'), 1000);
  assert.equal(toMs({ seconds: 12 }), 12000);
  assert.equal(toMs({ toMillis: () => 42 }), 42);
  assert.equal(toMs(null), null);
  assert.equal(toMs('garbage'), null);
});

test('dedupeEmails validates and de-duplicates case-insensitively', () => {
  assert.deepEqual(
    dedupeEmails([
      'excel_gesite@yahoo.com',
      'Excel_Gesite@Yahoo.com',
      ' invalid',
      'no-at-sign',
      'a b@c.com',
      'billing@citimovers.net',
    ]),
    ['excel_gesite@yahoo.com', 'billing@citimovers.net'],
  );
});

test('formatPicklist mirrors the app formatting', () => {
  assert.equal(
    formatPicklist([
      { item: 'Box A', quantity: '3', description: 'Fragile' },
      { item: 'Box B', quantity: '1' },
      { item: '', quantity: '' },
    ]),
    'Box A (Fragile) - 3\nBox B - 1',
  );
  assert.equal(formatPicklist(null), '');
});

test('collectUrlsByPrefix gathers nested photo arrays and de-duplicates', () => {
  const photos = {
    service_invoice_1: { url: 'https://x/inv1.png' },
    service_invoice_2: { url: 'https://x/inv2.png' },
    damaged_boxes_1: { url: 'https://x/dmg1.png' },
    damage_photos: [
      { url: 'https://x/dmg1.png' },
      { url: 'https://x/dmg2.png' },
    ],
    start_loading: { url: 'https://x/load.png' },
  };

  assert.deepEqual(collectUrlsByPrefix(photos, ['service_invoice_']), [
    'https://x/inv1.png',
    'https://x/inv2.png',
  ]);
  assert.deepEqual(
    collectUrlsByPrefix(photos, ['damaged_boxes', 'damage']),
    ['https://x/dmg1.png', 'https://x/dmg2.png'],
  );
});

test('photoUploadedAtMs walks the fallback chain', () => {
  const photos = {
    finish_loading: { url: 'https://x/f.png', uploadedAt: 5000 },
  };

  assert.equal(photoUploadedAtMs(photos, PHOTO_KEYS.loadingFinish), 5000);
  assert.equal(photoUploadedAtMs(photos, PHOTO_KEYS.unloadingStart), null);
});

test('firstPhotoUrl walks the fallback chain', () => {
  const photos = {
    finished_loading: { url: 'https://x/f.png' },
    start_loading: 'https://x/s.png',
  };

  assert.equal(
    firstPhotoUrl(photos, PHOTO_KEYS.loadingFinish),
    'https://x/f.png',
  );
  assert.equal(
    firstPhotoUrl(photos, PHOTO_KEYS.loadingStart),
    'https://x/s.png',
  );
  assert.equal(firstPhotoUrl(photos, PHOTO_KEYS.receiverId), '');
});

test('photoUrl reads strings and {url} objects only', () => {
  assert.equal(photoUrl('https://x/a.png'), 'https://x/a.png');
  assert.equal(photoUrl({ url: 'https://x/b.png' }), 'https://x/b.png');
  assert.equal(photoUrl({ uploadedAt: 1 }), '');
  assert.equal(photoUrl(null), '');
});
