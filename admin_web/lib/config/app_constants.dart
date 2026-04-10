class AdminConstants {
  // Hardcoded credentials — internal use only (v1 temporary)
  static const String adminUsername = 'admin';
  static const String adminPassword = 'CitiMoversAdmin2026';

  // Session storage key
  static const String sessionKey = 'admin_authenticated';

  // Firestore collections (using 'riders' as source of truth, not 'drivers')
  static const String colUsers = 'users';
  static const String colRiders = 'riders';
  static const String colBookings = 'bookings';
  static const String colTripCounters = 'trip_counters';
  static const String colDeliveryRequests = 'delivery_requests';
  static const String colWalletTransactions = 'wallet_transactions';
  static const String colPayments = 'payments';
  static const String colReviews = 'reviews';
  static const String colNotifications = 'notifications';
  static const String colPromoBanners = 'promo_banners';
  static const String colEmailNotifications = 'email_notifications';
  static const String colSavedLocations = 'saved_locations';
  static const String colPaymentMethods = 'payment_methods';
  static const String colRiderSettings = 'rider_settings';
  static const String colChatRooms = 'chatRooms';
  static const String colAdminAuditLogs = 'admin_audit_logs';
  static const String colBookingAdminNotes = 'admin_notes';

  // Booking statuses
  static const List<String> bookingStatuses = [
    'pending',
    'awaiting_payment',
    'payment_locked',
    'accepted',
    'arrived_at_pickup',
    'loading',
    'loading_complete',
    'in_transit',
    'arrived_at_dropoff',
    'unloading',
    'unloading_complete',
    'completed',
    'cancelled',
    'cancelled_by_rider',
    'cancelled_by_customer',
  ];

  // Audit action types
  static const String auditLogin = 'admin_login';
  static const String auditSuspendUser = 'suspend_user';
  static const String auditReactivateUser = 'reactivate_user';
  static const String auditWalletAdjust = 'wallet_adjust';
  static const String auditApproveRider = 'approve_rider';
  static const String auditRejectRiderDoc = 'reject_rider_document';
  static const String auditSuspendRider = 'suspend_rider';
  static const String auditReactivateRider = 'reactivate_rider';
  static const String auditAssignBooking = 'assign_booking';
  static const String auditCancelBooking = 'cancel_booking';
  static const String auditAddBookingNote = 'add_booking_note';
  static const String auditClaimBookingIssue = 'claim_booking_issue';
  static const String auditReleaseBookingIssue = 'release_booking_issue';
  static const String auditUpdateReconciliation = 'update_reconciliation';
  static const String auditPublishBanner = 'publish_promo_banner';
  static const String auditDeleteBanner = 'delete_promo_banner';
  static const String auditSendNotification = 'send_notification';
  static const String auditRunBackfill = 'run_backfill';
}
