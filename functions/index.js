/**
 * CitiMovers — delivery completion report sender.
 *
 * Why this exists
 * ---------------
 * The rider app historically sent report emails itself via EmailJS with the
 * recipient list compiled into the APK, so changing recipients required an
 * app update. This function moves sending server-side: it triggers whenever a
 * booking becomes "completed" and sends the report to the recipient list
 * stored in Firestore:
 *
 *   app_config/report_settings
 *     {
 *       "enabled": true,                          // master switch
 *       "recipients": ["excel_gesite@yahoo.com"]  // business recipients
 *     }
 *
 * Changing recipients (or turning reports off) is now a Firestore edit or an
 * "Report Settings" save in the admin panel — no APK, no Play Store update.
 *
 * Customer, driver, per-booking report recipients and partner report emails
 * are always included automatically (they are stamped on the booking).
 *
 * Duplicate protection: the function claims a booking via
 * `completionReportClaimedAt` before sending and records
 * `completionReportSentAt` / `completionReportStatus` afterwards. If the app
 * version installed on a rider's phone still sends its own copy, rotate the
 * EmailJS private key so old builds fail silently and this function remains
 * the single sender.
 */

const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const {
  PHOTO_KEYS,
  sleep,
  toMs,
  formatPht,
  formatPhtDateKey,
  formatPhtWallClock,
  firstPhotoUrl,
  photoUploadedAtMs,
  collectUrlsByPrefix,
  dedupeEmails,
  formatPicklist,
} = require('./report_helpers');

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ─── configuration ──────────────────────────────────────────────────────────

// EmailJS credentials — rotated keys (the previous keys remain compiled into
// old app builds, so they can no longer send; this function is the single
// sender). Override with environment variables (functions/.env) when rotating
// again.
const EMAILJS = {
  endpoint: 'https://api.emailjs.com/api/v1.0/email/send',
  serviceId: process.env.EMAILJS_SERVICE_ID || 'service_b5ez4ix',
  templateId: process.env.EMAILJS_TEMPLATE_ID || 'template_17hmw12',
  publicKey: process.env.EMAILJS_PUBLIC_KEY || 'EpmeCuNgroizNFX0Q',
  accessToken: process.env.EMAILJS_ACCESS_TOKEN || 'erJN0y2n12MKzlXEYTxAJ',
};

const REPORT_SETTINGS_DOC = 'app_config/report_settings';

// Fallback when the settings document does not exist yet.
const DEFAULT_RECIPIENTS = ['excel_gesite@yahoo.com'];

// Let the rider app finish flushing queued photo uploads before building the
// report (the app itself used to wait up to 30 s; photos keep uploading as
// the booking document receives updates).
const PHOTO_FLUSH_DELAY_MS = Number(process.env.REPORT_DELAY_MS || 120000);

// EmailJS rate limiting — the app used ~1.1 s between sends.
const SEND_GAP_MS = 1200;

// A claim older than this is considered abandoned (function crashed) and the
// next booking update may retry the report.
const CLAIM_STALE_MS = 10 * 60 * 1000;

// ─── data loading ───────────────────────────────────────────────────────────

async function loadReportSettings() {
  const snap = await db.doc(REPORT_SETTINGS_DOC).get();
  const data = snap.exists ? snap.data() : {};
  const enabled = data.enabled !== false;
  const recipients = dedupeEmails(
    Array.isArray(data.recipients) ? data.recipients : DEFAULT_RECIPIENTS,
  );
  return {
    enabled,
    recipients: recipients.length > 0 ? recipients : DEFAULT_RECIPIENTS,
  };
}

async function loadDoc(collection, id) {
  if (!id) return {};
  const snap = await db.collection(collection).doc(id).get();
  return snap.exists ? snap.data() : {};
}

function buildHelperFields(riderData) {
  const helper = (flatName, nestedKey, subField) => {
    const flat = riderData[flatName];
    if (typeof flat === 'string' && flat.trim() !== '') return flat.trim();
    const nested = riderData[nestedKey];
    if (nested && typeof nested === 'object') {
      const value = nested[subField];
      if (typeof value === 'string') return value.trim();
    }
    return '';
  };
  return {
    helper1_name: helper('helper1Name', 'helper1', 'name'),
    helper1_phone: helper('helper1Phone', 'helper1', 'phoneNumber'),
    helper2_name: helper('helper2Name', 'helper2', 'name'),
    helper2_phone: helper('helper2Phone', 'helper2', 'phoneNumber'),
  };
}

// ─── template building ──────────────────────────────────────────────────────

async function buildTemplateParams(bookingId, booking) {
  const riderId = booking.driverId || booking.riderId || '';
  const customerId = booking.customerId || booking.userId || '';
  const [riderData, customerData] = await Promise.all([
    loadDoc('riders', riderId),
    loadDoc('users', customerId),
  ]);

  const deliveryPhotos =
    booking.deliveryPhotos && typeof booking.deliveryPhotos === 'object'
      ? booking.deliveryPhotos
      : {};

  const plate = String(
    riderData.vehiclePlateNumber || riderData.plateNumber || '',
  );
  const vehicleType = String(
    riderData.vehicleType ||
      (booking.vehicle && (booking.vehicle.name || booking.vehicle.type)) ||
      '',
  );
  const pickupAddress = String(
    booking.pickupAddress || booking.pickupLocation?.address || '',
  );
  const dropoffAddress = String(
    booking.dropoffAddress || booking.dropoffLocation?.address || '',
  );

  const rddMs =
    toMs(booking.scheduledDateTime) ?? toMs(booking.createdAt) ?? Date.now();
  const rdd = formatPhtDateKey(rddMs);

  const warehouseArrivalAt =
    photoUploadedAtMs(deliveryPhotos, ['warehouse_arrival']) ??
    toMs(booking.arrivedAtPickupAt) ??
    toMs(booking.loadingStartedAt);
  const loadingStartAt = photoUploadedAtMs(
    deliveryPhotos,
    PHOTO_KEYS.loadingStart,
  );
  const loadingFinishAt =
    photoUploadedAtMs(deliveryPhotos, PHOTO_KEYS.loadingFinish) ??
    toMs(booking.loadingCompletedAt);
  const destinationArrivalAt =
    photoUploadedAtMs(deliveryPhotos, ['destination_arrival']) ??
    toMs(booking.arrivedAtDropoffAt) ??
    toMs(booking.unloadingStartedAt);
  const unloadingStartAt = photoUploadedAtMs(
    deliveryPhotos,
    PHOTO_KEYS.unloadingStart,
  );
  const unloadingFinishAt =
    photoUploadedAtMs(deliveryPhotos, PHOTO_KEYS.unloadingFinish) ??
    toMs(booking.unloadingCompletedAt);

  const receivedLabel =
    formatPhtWallClock(deliveryPhotos.receiver_signature_timestamp) ||
    formatPht(toMs(booking.completedAt)) ||
    formatPht(Date.now());

  const startLoadingUrl = firstPhotoUrl(
    deliveryPhotos,
    PHOTO_KEYS.loadingStart,
  );
  const finishLoadingUrl = firstPhotoUrl(
    deliveryPhotos,
    PHOTO_KEYS.loadingFinish,
  );
  const startUnloadingUrl = firstPhotoUrl(
    deliveryPhotos,
    PHOTO_KEYS.unloadingStart,
  );
  const finishUnloadingUrl = firstPhotoUrl(
    deliveryPhotos,
    PHOTO_KEYS.unloadingFinish,
  );

  const invoiceUrls = collectUrlsByPrefix(deliveryPhotos, [
    'service_invoice_',
  ]);
  const signedDocUrls = collectUrlsByPrefix(deliveryPhotos, [
    'signed_documents_',
  ]);
  const damagePhotoUrls = collectUrlsByPrefix(deliveryPhotos, [
    'damaged_boxes',
    'empty_truck',
    'damage',
  ]);

  const subject =
    `${vehicleType || 'TYPE'}_${plate || 'PLATE'}_${rdd}_Citimovers`;

  const additionalCharges = Array.isArray(booking.additionalCharges)
    ? booking.additionalCharges.filter(
        (charge) => charge && typeof charge === 'object',
      )
    : [];
  const additionalChargesTotal = additionalCharges.reduce(
    (sum, charge) => sum + Number(charge.amount || 0),
    0,
  );
  const additionalChargesText = additionalCharges
    .map(
      (charge) =>
        `${charge.label || charge.type || 'Charge'}: PHP ${Number(
          charge.amount || 0,
        ).toFixed(2)}`,
    )
    .join('\n');

  const params = {
    sender: 'pod@citimovers.net',
    receiver_name: String(booking.receiverName || riderData.name || ''),
    type: vehicleType,
    plate,
    driver_name: String(riderData.name || booking.driverName || ''),
    driver_phone: String(riderData.phoneNumber || booking.driverPhone || ''),
    ...buildHelperFields(riderData),
    pickup_address: pickupAddress,
    dropoff_address: dropoffAddress,
    destination_address: dropoffAddress,
    fo_number: '',
    trip_number: String(booking.tripNumber || bookingId),
    rdd,
    pickup_arrival_time: formatPht(warehouseArrivalAt),
    pickup_loading_start_time: formatPht(loadingStartAt),
    pickup_loading_finish_time: formatPht(loadingFinishAt),
    dropoff_arrival_time: formatPht(destinationArrivalAt),
    dropoff_unloading_start_time: formatPht(unloadingStartAt),
    dropoff_unloading_finish_time: formatPht(unloadingFinishAt),
    received_date_time: receivedLabel,
    received_timestamp_pht: receivedLabel,
    warehouse_arrival_photo_url: firstPhotoUrl(deliveryPhotos, [
      'warehouse_arrival',
    ]),
    destination_arrival_photo_url: firstPhotoUrl(deliveryPhotos, [
      'destination_arrival',
    ]),
    loading_photo_url: startLoadingUrl,
    unloading_photo_url: finishUnloadingUrl,
    start_loading_photo_url: startLoadingUrl,
    finish_loading_photo_url: finishLoadingUrl,
    start_unloading_photo_url: startUnloadingUrl,
    finish_unloading_photo_url: finishUnloadingUrl,
    receiver_id_photo_url: firstPhotoUrl(deliveryPhotos, PHOTO_KEYS.receiverId),
    receiver_signature_url: firstPhotoUrl(
      deliveryPhotos,
      PHOTO_KEYS.receiverSignature,
    ),
    damage_photo_urls: damagePhotoUrls.join('\n'),
    damage_photo_count: String(damagePhotoUrls.length),
    service_invoice_urls: invoiceUrls.join('\n'),
    signed_document_urls: signedDocUrls.join('\n'),
    signed_document_count: String(signedDocUrls.length),
    additional_charges: additionalChargesText,
    additional_charges_total: additionalChargesTotal.toFixed(2),
    picklist_items: formatPicklist(booking.picklistItems),
    bcc_emails: '',
    cc_emails: '',
  };

  return {
    params,
    subject,
    customerEmail: String(customerData.email || ''),
    driverEmail: String(riderData.email || ''),
  };
}

function resolveRecipients(settings, template, booking) {
  const extras = [];
  extras.push(...settings.recipients);
  extras.push(template.customerEmail);
  extras.push(template.driverEmail);

  const reportRecipients = booking.reportRecipients;
  if (Array.isArray(reportRecipients)) {
    extras.push(...reportRecipients);
  } else if (typeof reportRecipients === 'string') {
    extras.push(...reportRecipients.split(','));
  }

  if (Array.isArray(booking.partnerReportEmails)) {
    extras.push(...booking.partnerReportEmails);
  }

  return dedupeEmails(extras);
}

// ─── sending ────────────────────────────────────────────────────────────────

async function sendEmail(to, subject, params) {
  const response = await fetch(EMAILJS.endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      service_id: EMAILJS.serviceId,
      template_id: EMAILJS.templateId,
      user_id: EMAILJS.publicKey,
      accessToken: EMAILJS.accessToken,
      template_params: { ...params, to_email: to, email: to, subject },
    }),
  });

  if (response.status < 200 || response.status >= 300) {
    const body = await response.text().catch(() => '');
    throw new Error(
      `EmailJS ${response.status} for ${to}: ${body.slice(0, 300)}`,
    );
  }
}

async function claimReport(bookingRef) {
  return db.runTransaction(async (txn) => {
    const snap = await txn.get(bookingRef);
    const data = snap.data() || {};
    if (data.completionReportSentAt) return false;

    const claimedAt = toMs(data.completionReportClaimedAt);
    if (claimedAt && Date.now() - claimedAt < CLAIM_STALE_MS) {
      return false; // another invocation is already handling this booking
    }

    txn.set(
      bookingRef,
      { completionReportClaimedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return true;
  });
}

// ─── trigger ────────────────────────────────────────────────────────────────

exports.sendCompletionReport = onDocumentUpdated(
  {
    document: 'bookings/{bookingId}',
    timeoutSeconds: 540,
    memory: '256MiB',
  },
  async (event) => {
    const after = event.data?.after?.data() ?? {};
    const bookingRef = event.data.after.ref;

    if (after.status !== 'completed') return;
    if (after.completionReportSentAt) return;

    const claimed = await claimReport(bookingRef);
    if (!claimed) {
      logger.info(
        `Report already sent or in flight for booking ${event.params.bookingId}`,
      );
      return;
    }

    const settings = await loadReportSettings();
    if (!settings.enabled) {
      logger.info('Completion reports disabled in report_settings.');
      await bookingRef.set(
        {
          completionReportStatus: 'disabled',
          completionReportClaimedAt: FieldValue.delete(),
        },
        { merge: true },
      );
      return;
    }

    try {
      logger.info(
        `Building completion report for booking ${event.params.bookingId} ` +
          `(waiting ${PHOTO_FLUSH_DELAY_MS} ms for photo uploads)`,
      );
      await sleep(PHOTO_FLUSH_DELAY_MS);

      // Re-read: the rider app may have flushed more photos while waiting.
      const freshSnap = await bookingRef.get();
      const booking = freshSnap.data() || after;

      const template = await buildTemplateParams(
        event.params.bookingId,
        booking,
      );
      const recipients = resolveRecipients(settings, template, booking);

      let sentCount = 0;
      const failures = [];
      for (const to of recipients) {
        try {
          await sendEmail(to, template.subject, template.params);
          sentCount += 1;
          logger.info(`Report sent to ${to}`);
        } catch (error) {
          failures.push(`${to}: ${error.message}`);
          logger.error(`Report send failed for ${to}: ${error.message}`);
        }
        await sleep(SEND_GAP_MS);
      }

      await bookingRef.set(
        {
          completionReportStatus: failures.length === 0 ? 'sent' : 'partial',
          completionReportSentAt: FieldValue.serverTimestamp(),
          completionReportSentCount: sentCount,
          completionReportFailedCount: failures.length,
          completionReportRecipients: recipients,
          completionReportErrors: failures.slice(0, 10),
          completionReportClaimedAt: FieldValue.delete(),
        },
        { merge: true },
      );

      logger.info(
        `Completion report for ${event.params.bookingId}: ` +
          `${sentCount} sent, ${failures.length} failed.`,
      );
    } catch (error) {
      logger.error(
        `Completion report failed for ${event.params.bookingId}: ` +
          `${error.message}`,
      );
      await bookingRef.set(
        {
          completionReportStatus: 'failed',
          completionReportError: String(error.message || error).slice(0, 500),
          completionReportClaimedAt: FieldValue.delete(),
        },
        { merge: true },
      );
    }
  },
);
