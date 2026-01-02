# CitiMovers - Customer Interface TODO List

This document tracks all TODO items for the customer interface, including implementation status and file locations.

---

## ✅ COMPLETED ITEMS

### 1. Firebase Email Verification
- **File:** [`lib/services/auth_service.dart`](lib/services/auth_service.dart:158-197)
- **Status:** ✅ COMPLETED
- **Details:**
  - Implemented `sendEmailVerificationCode()` method using Firebase Auth
  - Creates temporary Firebase Auth user with email/password
  - Sends verification email via Firebase Auth
  - Handles email-already-in-use error gracefully
  - Added `emailVerified` field to [`UserModel`](lib/models/user_model.dart:10)

### 2. Firebase Password Change
- **File:** [`lib/services/auth_service.dart`](lib/services/auth_service.dart:406-447)
- **Status:** ✅ COMPLETED
- **Details:**
  - Implemented `changePassword()` method using Firebase Auth
  - Requires re-authentication with current password
  - Handles wrong-password and weak-password errors
  - Added `resetPassword()` method for password reset via email

### 3. Share Functionality (Terms & Conditions)
- **File:** [`lib/screens/terms_conditions_screen.dart`](lib/screens/terms_conditions_screen.dart:1-24)
- **Status:** ✅ COMPLETED
- **Details:**
  - Added `share_plus` package to [`pubspec.yaml`](pubspec.yaml:48)
  - Implemented `_shareTermsAndConditions()` method
  - Shares key points of terms and conditions
  - Uses `Share.share()` with subject and text

### 4. Share Functionality (Privacy Policy)
- **File:** [`lib/screens/privacy_policy_screen.dart`](lib/screens/privacy_policy_screen.dart:1-28)
- **Status:** ✅ COMPLETED
- **Details:**
  - Implemented `_sharePrivacyPolicy()` method
  - Shares key points of privacy policy
  - Uses `Share.share()` with subject and text

### 5. Notifications Settings Screen
- **File:** [`lib/screens/profile/notifications_settings_screen.dart`](lib/screens/profile/notifications_settings_screen.dart)
- **Status:** ✅ COMPLETED
- **Details:**
  - Created full notifications settings screen
  - `NotificationPreferences` model with 7 settings
  - Settings: Push, Email, SMS, Booking Updates, Driver Updates, Payment Alerts, Promotional Offers
  - Persists to GetStorage
  - Updated [`profile_screen.dart`](lib/screens/profile/profile_screen.dart:329-342) to navigate to new screen

### 6. Language Settings Screen
- **File:** [`lib/screens/profile/language_settings_screen.dart`](lib/screens/profile/language_settings_screen.dart)
- **Status:** ✅ COMPLETED
- **Details:**
  - Created full language settings screen
  - Supports 6 languages: English, Filipino, Spanish, Chinese, Japanese, Korean
  - Each language has flag emoji, display name, and code
  - Persists to GetStorage
  - Updated [`profile_screen.dart`](lib/screens/profile/profile_screen.dart:343-357) to navigate to new screen

---

## 🚫 EXCLUDED ITEMS (Per User Request)

### 1. Payment Gateway Integration
- **Files:**
  - [`lib/services/payment_service.dart`](lib/services/payment_service.dart)
  - [`lib/screens/booking/booking_summary_screen.dart`](lib/screens/booking/booking_summary_screen.dart)
- **Status:** 🚫 EXCLUDED
- **Reason:** User requested to exclude payment gateway implementation
- **Details:**
  - GCash integration
  - PayMaya integration
  - Stripe integration
  - Payment processing after booking
  - Payment method management

### 2. Email Sending (Cloud Functions/Backend)
- **Files:**
  - [`lib/services/email_notification_service.dart`](lib/services/email_notification_service.dart)
  - [`lib/rider/screens/delivery/rider_delivery_progress_screen.dart`](lib/rider/screens/delivery/rider_delivery_progress_screen.dart:546)
- **Status:** 🚫 EXCLUDED
- **Reason:** User requested to exclude email sending implementation
- **Details:**
  - Actual email sending after booking
  - Email sending after delivery completion
  - Requires Firebase Cloud Functions or backend service
  - Would use providers like SendGrid, Mailgun, or AWS SES

---

## 📋 ALL OTHER FIREBASE INTEGRATIONS COMPLETED

### Booking Flow
- ✅ Booking creation with Firestore
- ✅ Booking status updates
- ✅ Booking history retrieval
- ✅ Review submission
- ✅ Tip processing
- ✅ Delivery photo uploads to Firebase Storage

### Real-time Features
- ✅ Real-time driver location tracking via Firebase Realtime Database
- ✅ Booking status streaming via Firestore snapshots
- ✅ Rider location streaming for customers

### Notifications
- ✅ Booking status notifications
- ✅ Review notifications
- ✅ Delivery request notifications
- ✅ Notification storage in Firestore

### User Management
- ✅ User registration with Firestore
- ✅ User login via phone + OTP
- ✅ Profile updates
- ✅ Profile photo uploads to Firebase Storage
- ✅ Account deletion

### Saved Locations
- ✅ Save location to Firestore
- ✅ Retrieve saved locations
- ✅ Delete saved location

### Promo Banners
- ✅ Fetch promo banners from Firestore
- ✅ Display promo banners on home screen

### Payment Methods
- ✅ Store payment methods in Firestore
- ✅ Retrieve payment methods
- ✅ Delete payment methods

### Wallet
- ✅ Wallet balance tracking
- ✅ Transaction history
- ✅ Wallet updates via Firestore transactions

---

## 📦 DEPENDENCIES ADDED

### pubspec.yaml
- `share_plus: ^7.2.1` - For share functionality

---

## 🔧 MODELS UPDATED

### UserModel
- Added `emailVerified` field (bool?)
- Updated `toMap()` method
- Updated `fromMap()` factory
- Updated `copyWith()` method

---

## 📝 NOTES

1. **Email Verification Flow:** The current implementation creates a temporary Firebase Auth user and sends a verification email. In production, consider using Firebase Auth's email link verification or implement a custom OTP system via EmailNotificationService.

2. **Password Change:** This feature requires the user to have a Firebase Auth account with email/password. For phone-based authentication, consider implementing a "Change Phone Number" feature instead.

3. **Language Settings:** The language preference is saved to GetStorage. In a production app, you would typically use a localization package like `flutter_localizations` and update the app's locale when the language changes.

4. **Notification Settings:** Preferences are saved to GetStorage. In production, you may want to sync these with Firestore for cross-device synchronization.

5. **Share Functionality:** The share feature shares a summary of the terms/privacy policy. For full content sharing, consider implementing a web view with the full content that can be shared as a URL.

---

## 🚀 NEXT STEPS (Optional)

1. **Payment Gateway Integration:** Implement GCash, PayMaya, or Stripe for actual payment processing
2. **Email Sending:** Set up Firebase Cloud Functions or backend service for actual email sending
3. **Localization:** Implement full app localization using `flutter_localizations` package
4. **Push Notifications:** Implement Firebase Cloud Messaging (FCM) for push notifications
5. **Deep Linking:** Implement deep linking for booking sharing and referral system

---

## 📄 RELATED DOCUMENTS

- [`README_RIDER.md`](README_RIDER.md) - Rider interface TODO list
- [`pubspec.yaml`](pubspec.yaml) - Project dependencies
- [`lib/firebase_options.dart`](lib/firebase_options.dart) - Firebase configuration

---

**Last Updated:** 2025-12-23
**Status:** Customer interface TODO items (excluding payment gateway and email sending) are completed.
