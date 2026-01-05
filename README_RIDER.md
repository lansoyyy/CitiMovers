# CitiMovers - Rider Interface TODO List

This document tracks all TODO items for rider interface, including implementation status and file locations.

---

## ⚠️ CONFIGURATION REQUIRED

### Google Maps API Key
- **File:** [`lib/services/maps_service.dart`](lib/services/maps_service.dart:15)
- **Status:** ⚠️ NEEDS USER ACTION
- **Details:**
  - The app uses a placeholder Google Maps API key
  - Replace `'AIzaSyBwByaaKz7j4OGnwPDxeMdmQ4Pa50GA42o'` with your actual API key
  - Without a valid API key, the app will use mock data for maps functionality

---

## 🚫 EXCLUDED ITEMS (Per User Request)

### 1. Payment Gateway Integration
- **Files:**
  - [`lib/services/payment_service.dart`](lib/services/payment_service.dart)
  - [`lib/rider/screens/profile/rider_payment_methods_screen.dart`](lib/rider/screens/profile/rider_payment_methods_screen.dart)
- **Status:** 🚫 EXCLUDED
- **Reason:** User requested to exclude payment gateway implementation
- **Details:**
  - GCash integration for rider payments
  - PayMaya integration for rider payments
  - Stripe integration for rider payments
  - Earnings withdrawal processing
  - Payment method management for riders

### 2. Email Sending (Cloud Functions/Backend)
- **Files:**
  - [`lib/services/email_notification_service.dart`](lib/services/email_notification_service.dart)
  - [`lib/rider/screens/delivery/rider_delivery_progress_screen.dart`](lib/rider/screens/delivery/rider_delivery_progress_screen.dart:546)
- **Status:** 🚫 EXCLUDED
- **Reason:** User requested to exclude email sending implementation
- **Details:**
  - Email sending to customer after delivery completion
  - Email sending to admin after delivery completion
  - Email sending to driver after delivery completion
  - Requires Firebase Cloud Functions or backend service
  - Would use providers like SendGrid, Mailgun, or AWS SES

---

## 📋 ALL FIREBASE INTEGRATIONS COMPLETED

### Rider Authentication
- ✅ Rider registration with Firestore
- ✅ Rider login via phone + OTP
- ✅ Rider profile updates
- ✅ Rider photo uploads to Firebase Storage
- ✅ Rider account deletion
- ✅ Real-time location tracking via Firebase Realtime Database
  - **File:** [`lib/rider/services/rider_location_service.dart`](lib/rider/services/rider_location_service.dart)
  - **Service:** `RiderLocationService` for real-time rider location updates
  - **Integration:** Integrated into [`RiderAuthService`](lib/rider/services/rider_auth_service.dart) and [`RiderDeliveryProgressScreen`](lib/rider/screens/delivery/rider_delivery_progress_screen.dart)

### Rider Profile Management
- ✅ Profile updates
- ✅ Vehicle details management
- ✅ Documents upload to Firebase Storage
- ✅ Payment methods management (storage only, no actual processing)
- ✅ Delivery history
- ✅ Earnings tracking
- ✅ Settings management

### Delivery Request Management
- ✅ Fetch available delivery requests
- ✅ Accept delivery request
- ✅ Reject delivery request
- ✅ Delivery request creation on customer booking
  - **File:** [`lib/services/booking_service.dart`](lib/services/booking_service.dart)

### Delivery Progress Tracking
- ✅ Update delivery status (Firestore)
- ✅ Upload delivery photos to Firebase Storage
- ✅ Track rider location in real-time
- ✅ Calculate and save demurrage charges
- ✅ Complete delivery
- ✅ Mock email sending (for future implementation)

### Notifications
- ✅ Booking status notifications
- ✅ Review notifications
- ✅ Delivery request notifications
- ✅ Notification storage in Firestore
- ✅ Rider notifications screen

### Wallet Service
- ✅ Wallet balance tracking
- ✅ Transaction history
- ✅ Wallet updates via Firestore transactions
- ✅ Earnings calculation
- **File:** [`lib/services/wallet_service.dart`](lib/services/wallet_service.dart)

---

## 📁 RIDER INTERFACE FILE STRUCTURE

### Authentication
- [`lib/rider/screens/auth/rider_splash_screen.dart`](lib/rider/screens/auth/rider_splash_screen.dart) - Splash screen
- [`lib/rider/screens/auth/rider_onboarding_screen.dart`](lib/rider/screens/auth/rider_onboarding_screen.dart) - Onboarding
- [`lib/rider/screens/auth/rider_login_screen.dart`](lib/rider/screens/auth/rider_login_screen.dart) - Login
- [`lib/rider/screens/auth/rider_signup_screen.dart`](lib/rider/screens/auth/rider_signup_screen.dart) - Signup
- [`lib/rider/screens/auth/rider_otp_verification_screen.dart`](lib/rider/screens/auth/rider_otp_verification_screen.dart) - OTP verification

### Home & Tabs
- [`lib/rider/screens/rider_home_screen.dart`](lib/rider/screens/rider_home_screen.dart) - Main home screen
- [`lib/rider/screens/tabs/rider_home_tab.dart`](lib/rider/screens/tabs/rider_home_tab.dart) - Home tab
- [`lib/rider/screens/tabs/rider_deliveries_tab.dart`](lib/rider/screens/tabs/rider_deliveries_tab.dart) - Deliveries tab
- [`lib/rider/screens/tabs/rider_earnings_tab.dart`](lib/rider/screens/tabs/rider_earnings_tab.dart) - Earnings tab
- [`lib/rider/screens/tabs/rider_notifications_tab.dart`](lib/rider/screens/tabs/rider_notifications_tab.dart) - Notifications tab
- [`lib/rider/screens/tabs/rider_profile_tab.dart`](lib/rider/screens/tabs/rider_profile_tab.dart) - Profile tab

### Delivery
- [`lib/rider/screens/delivery/rider_delivery_progress_screen.dart`](lib/rider/screens/delivery/rider_delivery_progress_screen.dart) - Active delivery tracking

### Profile
- [`lib/rider/screens/profile/rider_edit_profile_screen.dart`](lib/rider/screens/profile/rider_edit_profile_screen.dart) - Edit profile
- [`lib/rider/screens/profile/rider_vehicle_details_screen.dart`](lib/rider/screens/profile/rider_vehicle_details_screen.dart) - Vehicle details
- [`lib/rider/screens/profile/rider_documents_screen.dart`](lib/rider/screens/profile/rider_documents_screen.dart) - Documents
- [`lib/rider/screens/profile/rider_payment_methods_screen.dart`](lib/rider/screens/profile/rider_payment_methods_screen.dart) - Payment methods
- [`lib/rider/screens/profile/rider_delivery_history_screen.dart`](lib/rider/screens/profile/rider_delivery_history_screen.dart) - Delivery history
- [`lib/rider/screens/profile/rider_settings_screen.dart`](lib/rider/screens/profile/rider_settings_screen.dart) - Settings

### Notifications
- [`lib/rider/screens/rider_notifications_screen.dart`](lib/rider/screens/rider_notifications_screen.dart) - Notifications list

### Services
- [`lib/rider/services/rider_auth_service.dart`](lib/rider/services/rider_auth_service.dart) - Rider authentication
- [`lib/rider/services/rider_location_service.dart`](lib/rider/services/rider_location_service.dart) - Real-time location tracking

### Models
- [`lib/rider/models/rider_model.dart`](lib/rider/models/rider_model.dart) - Rider data model
- [`lib/rider/models/delivery_request_model.dart`](lib/rider/models/delivery_request_model.dart) - Delivery request model
- [`lib/rider/models/rider_notification_model.dart`](lib/rider/models/rider_notification_model.dart) - Rider notification model

---

## 🔧 RIDER-SPECIFIC FEATURES

### Real-time Location Tracking
- **File:** [`lib/rider/services/rider_location_service.dart`](lib/rider/services/rider_location_service.dart)
- **Implementation:**
  - Uses Firebase Realtime Database
  - Path: `rider_locations/{riderId}`
  - Updates: latitude, longitude, timestamp
  - Stream: Real-time location updates for customers

### Delivery Request Flow
1. Customer creates booking → Delivery request created in Firestore
2. Rider fetches available requests via `getDeliveryRequests()`
3. Rider accepts/rejects request via `acceptDeliveryRequest()`/`rejectDeliveryRequest()`
4. Booking status updated to `accepted`/`rejected`
5. Rider starts delivery via `RiderDeliveryProgressScreen`

### Delivery Status Flow
1. `pending` - Initial state
2. `accepted` - Rider accepted request
3. `arrived_at_pickup` - Rider at pickup location
4. `loading_complete` - Items loaded
5. `in_transit` - En route to destination
6. `arrived_at_dropoff` - At delivery location
7. `unloading_complete` - Items unloaded
8. `completed` - Delivery finished

### Demurrage Calculation
- 25% of fare per 4-hour block
- Saved to booking document
- Automatically calculated based on loading/unloading time

---

## 📦 SHARED SERVICES USED BY RIDER INTERFACE

### BookingService
- **File:** [`lib/services/booking_service.dart`](lib/services/booking_service.dart)
- **Used for:**
  - Creating delivery requests
  - Accepting/rejecting requests
  - Updating delivery status
  - Submitting reviews
  - Managing delivery photos

### NotificationService
- **File:** [`lib/services/notification_service.dart`](lib/services/notification_service.dart)
- **Used for:**
  - Sending booking notifications
  - Sending review notifications
  - Sending delivery request notifications

### StorageService
- **File:** [`lib/services/storage_service.dart`](lib/services/storage_service.dart)
- **Used for:**
  - Uploading rider photos
  - Uploading vehicle photos
  - Uploading documents
  - Uploading delivery photos

### WalletService
- **File:** [`lib/services/wallet_service.dart`](lib/services/wallet_service.dart)
- **Used for:**
  - Tracking rider earnings
  - Managing wallet balance
  - Transaction history

---

## 🚫 TODO ITEMS NOT APPLICABLE TO RIDER INTERFACE

The following TODO items are customer-specific and do not apply to rider interface:

1. **Language Settings Screen** - Customer only
2. **Customer Profile Settings** - Customer only
3. **Customer Booking Flow** - Customer only
4. **Customer Saved Locations** - Customer only
5. **Customer Wallet** - Customer only (riders have earnings, not wallet)

---

## 📝 NOTES

1. **Email Sending Mock:** The rider delivery progress screen has mock email sending functionality. This is intentional as actual email sending requires Firebase Cloud Functions or a backend service, which is excluded per user request.

2. **Geofencing:** The delivery progress screen mentions geofencing for delivery area verification. This is currently mocked and would require geofencing libraries like `geofencing` or custom implementation using `geolocator`.

3. **Payment Methods:** The rider payment methods screen only stores payment methods in Firestore. Actual payment processing (GCash, PayMaya, Stripe) is excluded per user request.

4. **Real-time Location:** Rider location is tracked using Firebase Realtime Database. This allows customers to see real-time rider location during delivery.

---

## 🚀 NEXT STEPS (Optional)

1. **Payment Gateway Integration:** Implement GCash, PayMaya, or Stripe for rider earnings withdrawal
2. **Email Sending:** Set up Firebase Cloud Functions or backend service for actual email sending
3. **Push Notifications:** Implement Firebase Cloud Messaging (FCM) for rider push notifications
4. **Geofencing:** Implement geofencing for automatic delivery area verification
5. **Earnings Analytics:** Add detailed earnings analytics and charts
6. **Rating System:** Implement rider rating system from customers

---

## 📄 RELATED DOCUMENTS

- [`README_CUSTOMER.md`](README_CUSTOMER.md) - Customer interface TODO list
- [`pubspec.yaml`](pubspec.yaml) - Project dependencies
- [`lib/firebase_options.dart`](lib/firebase_options.dart) - Firebase configuration

---

**Last Updated:** 2025-12-23
**Status:** All rider interface Firebase integrations are completed. Excluded: Payment gateway and email sending.
