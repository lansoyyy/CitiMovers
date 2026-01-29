# Critical Issues Fixes - CitiMovers
**Date:** 2026-01-29  
**Status:** All Critical Issues Fixed

---

## Summary

All 4 Critical Issues (Must Fix Before Production) have been addressed. The payment flow inconsistency issue was skipped as per user's confirmation that they are using cash-only payments until Dragonpay account is set up.

---

## Fixed Issues

### 1. ✅ Dragonpay Password Exposed in Client Code
**File:** [`lib/services/dragonpay_status_service.dart`](lib/services/dragonpay_status_service.dart:1)

**Changes Made:**
- Disabled the `getStatus()` method that exposes merchant password
- Added clear documentation noting the service is disabled for cash-only payments
- Commented out the original implementation for future use
- Added Flutter import for `debugPrint`

**Security Impact:**
- Merchant credentials no longer exposed in compiled app
- Status checking will be re-enabled when moved to backend/Cloud Functions

**Code Changes:**
```dart
// Disabled for cash-only payments
// TODO: Re-enable when Dragonpay is integrated via backend/Cloud Functions
debugPrint('Dragonpay status checking disabled - cash-only mode');
return null;
```

---

### 2. ✅ OTP Storage in Memory - Now Secure with Firestore
**File:** [`lib/services/otp_service.dart`](lib/services/otp_service.dart:1)

**Changes Made:**
- Removed in-memory Map storage (`_tempOtpStorage`)
- Implemented Firestore-based OTP storage with TTL (5 minutes expiration)
- Added rate limiting (max 3 requests per 15 minutes)
- Added attempt tracking (max 3 failed attempts before blocking)
- Added OTP expiration checking
- Added cleanup method for expired OTPs

**Security Impact:**
- OTPs now stored securely in Firestore
- OTPs expire after 5 minutes
- Rate limiting prevents abuse
- Failed attempts are tracked and blocked after threshold

**New Features:**
- `sendOtp()` - Generates OTP, stores in Firestore with expiration, sends via SMS
- `verifyOtp()` - Verifies OTP against stored value with expiration and attempt checking
- `cleanupExpiredOtps()` - Removes expired OTPs from Firestore

**Firestore Collections Created:**
- `otps` - Stores OTP codes with expiration and attempt tracking
- `otp_rate_limits` - Tracks rate limits per phone number

---

### 3. ✅ Email Verification Bypassed - Now Proper Implementation
**File:** [`lib/services/auth_service.dart`](lib/services/auth_service.dart:1)

**Changes Made:**
- Removed mock implementation that accepted any 6-digit code
- Implemented proper email verification using OTP stored in Firestore
- Added EmailJS integration for sending verification codes
- Added rate limiting (max 3 requests per 15 minutes)
- Added attempt tracking (max 3 failed attempts)
- Added OTP expiration (5 minutes)
- Added proper user emailVerified status update in Firestore

**Security Impact:**
- Email verification now requires valid OTP code
- OTPs expire after 5 minutes
- Rate limiting prevents abuse
- Failed attempts are tracked

**New Features:**
- `sendEmailVerificationCode()` - Generates OTP, stores in Firestore, sends via EmailJS
- `verifyEmailCode()` - Verifies OTP against stored value with all validations

**Firestore Collections Created:**
- `email_verification_otps` - Stores email verification OTPs
- `email_verification_rate_limits` - Tracks rate limits per email address

**EmailJS Template Parameters Required:**
```javascript
{
  'otp_code': '123456',
  'expiry_minutes': '5'
}
```

---

### 4. ✅ No Transaction Atomicity for Booking Creation
**File:** [`lib/services/booking_service.dart`](lib/services/booking_service.dart:20)

**Changes Made:**
- Wrapped booking creation in Firestore transaction
- Ensures atomic creation of both `bookings` and `delivery_requests` documents
- Added duplicate booking check in transaction
- If transaction fails, neither document is created (prevents orphaned delivery requests)

**Data Integrity Impact:**
- Booking and delivery request are created atomically
- No orphaned delivery requests without bookings
- No data inconsistency if one write fails

**Code Changes:**
```dart
await _firestore.runTransaction((transaction) async {
  // Check if booking already exists
  final bookingSnapshot = await transaction.get(bookingRef);
  if (bookingSnapshot.exists) {
    throw Exception('Booking already exists: $bookingId');
  }

  // Create booking document
  transaction.set(bookingRef, {...});

  // Create delivery request document
  transaction.set(deliveryRequestRef, {...});
});
```

---

## Firestore Security Rules Needed

Add these security rules to `firestore.rules`:

### OTP Collection
```javascript
match /otps/{otpId} {
  allow create: if request.auth != null;
  allow read, update: if request.auth != null;
  allow delete: if false; // Only cleanup via Cloud Functions
}

match /otp_rate_limits/{phoneNumber} {
  allow read, write: if request.auth != null;
}
```

### Email Verification OTP Collection
```javascript
match /email_verification_otps/{otpId} {
  allow create: if request.auth != null;
  allow read, update: if request.auth != null;
  allow delete: if false; // Only cleanup via Cloud Functions
}

match /email_verification_rate_limits/{email} {
  allow read, write: if request.auth != null;
}
```

---

## Recommended Next Steps

### High Priority Issues to Fix Next
1. Configure Google Maps API key
2. Fix demurrage timer lifecycle issues
3. Consolidate location tracking to single database
4. Standardize data model serialization
5. Add proper error handling throughout

### Cloud Functions to Implement
1. **OTP Cleanup** - Periodically delete expired OTPs
2. **Email Verification Cleanup** - Periodically delete expired email OTPs
3. **Dragonpay Status Check** - Move payment status checking to backend
4. **Demurrage Calculation** - Server-side calculation to prevent client manipulation

### Testing Required
1. Test OTP sending and verification flow
2. Test email verification flow
3. Test booking creation with transaction
4. Test rate limiting for OTP and email verification
5. Test OTP expiration behavior

---

## Notes

### Payment Gateway Integration
When Dragonpay account is set up:
1. Create Cloud Function for payment status checking
2. Remove hardcoded "Cash" enforcement from [`booking_service.dart`](lib/services/booking_service.dart:40)
3. Re-enable Dragonpay status service
4. Test complete payment flow

### EmailJS Configuration
Ensure EmailJS template is configured with these parameters:
- `{{otp_code}}` - The 6-digit verification code
- `{{expiry_minutes}}` - Expiration time in minutes (5)
- `{{to_email}}` - Recipient email address

---

**Fixes Completed By:** Code Review System  
**Fixes Version:** 1.0  
**Last Updated:** 2026-01-29
