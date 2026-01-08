# CitiMovers - Email & Payment Gateway Integration Plan

## Table of Contents
1. [Email Integration Plan](#email-integration-plan)
2. [Payment Gateway Integration Plan (Dragonpay)](#payment-gateway-integration-plan-dragonpay)
3. [Payment Gateway Loopholes & Solutions](#payment-gateway-loopholes--solutions)

---

## Email Integration Plan

### Option 1: Mailgun (Recommended)

#### Why Mailgun?
- Better free tier: 5,000 emails/month vs 100/day (SendGrid)
- Lower cost at scale: $35/50K emails
- Simple REST API
- Good deliverability in Philippines
- SMS integration available via parent company Sinch

#### Implementation Approach: Firebase Extensions + Mailgun

**No Cloud Functions code required.** Use Firebase Extensions for simplest implementation.

---

### Files to Modify/Update

#### 1. Configuration Files

| File | Changes Required |
|------|-----------------|
| [`pubspec.yaml`](../pubspec.yaml) | Add `cloud_firestore: ^4.0.0` (already added) |
| `firebase.json` | Create Firebase config for extensions |

#### 2. Service Files

| File | Changes Required |
|------|-----------------|
| [`lib/services/email_notification_service.dart`](../lib/services/email_notification_service.dart) | ✅ Already updated to use `mail` collection for Firebase Extensions |

#### 3. No Code Changes Needed

The [`EmailNotificationService`](../lib/services/email_notification_service.dart) is already configured to work with Firebase Extensions. It writes to the `mail` collection which triggers the Mailgun extension.

---

### Setup Steps

#### Step 1: Install Firebase CLI
```bash
npm install -g firebase-tools
```

#### Step 2: Login to Firebase
```bash
firebase login
```

#### Step 3: Navigate to Project
```bash
cd "d:/Flutter Projects/citimovers"
```

#### Step 4: Initialize Firebase (if not done)
```bash
firebase init
```

#### Step 5: Install Mailgun Extension
```bash
firebase extensions:install mailgun/send-email --project=your-project-id
```

#### Step 6: Configure Extension
When prompted, provide:
- **Mailgun API Key**: Get from mailgun.com
- **Mailgun Domain**: Your verified domain (e.g., `mg.citimovers.com`)
- **Default Sender Email**: `noreply@citimovers.com`
- **Default Sender Name**: `CitiMovers`

#### Step 7: Deploy Extension
```bash
firebase deploy --only extensions
```

---

### Email Types Already Implemented

The following email templates are already in [`lib/services/email_notification_service.dart`](../lib/services/email_notification_service.dart):

| Email Type | Method | Used By |
|------------|---------|----------|
| Booking Confirmation | `sendBookingConfirmationEmail()` | Customer - After booking |
| Rider Assigned | `sendRiderAssignedEmail()` | Customer - When rider accepts |
| Delivery Completed | `sendDeliveryCompletedEmail()` | Customer - After delivery |
| OTP Verification | `sendOtpEmail()` | Both - Registration/Login/Reset |
| Password Reset | `sendPasswordResetEmail()` | Both - Password recovery |
| Payment Confirmation | `sendPaymentConfirmationEmail()` | Customer - After payment |
| Wallet Top-up | `sendWalletTopUpEmail()` | Both - Wallet transactions |
| Rider Earnings | `sendEarningNotificationEmail()` | Rider - After delivery |
| Promotional | `sendPromotionalEmail()` | Both - Marketing emails |

---

### Where Emails Are Sent

#### Customer Interface
| Screen/Feature | Email Trigger |
|----------------|---------------|
| [`lib/screens/auth/signup_screen.dart`](../lib/screens/auth/signup_screen.dart) | OTP for registration |
| [`lib/screens/auth/login_screen.dart`](../lib/screens/auth/login_screen.dart) | OTP for login |
| [`lib/screens/auth/email_verification_screen.dart`](../lib/screens/auth/email_verification_screen.dart) | Email verification |
| [`lib/screens/booking/booking_summary_screen.dart`](../lib/screens/booking/booking_summary_screen.dart) | Booking confirmation |
| [`lib/screens/delivery/delivery_tracking_screen.dart`](../lib/screens/delivery/delivery_tracking_screen.dart) | Rider assigned, delivery updates |
| [`lib/screens/delivery/delivery_completion_screen.dart`](../lib/screens/delivery/delivery_completion_screen.dart) | Delivery completed |
| [`lib/screens/profile/change_password_screen.dart`](../lib/screens/profile/change_password_screen.dart) | Password reset |

#### Rider Interface
| Screen/Feature | Email Trigger |
|----------------|---------------|
| [`lib/rider/screens/auth/rider_signup_screen.dart`](../lib/rider/screens/auth/rider_signup_screen.dart) | OTP for registration |
| [`lib/rider/screens/auth/rider_login_screen.dart`](../lib/rider/screens/auth/rider_login_screen.dart) | OTP for login |
| [`lib/rider/screens/delivery/rider_delivery_progress_screen.dart`](../lib/rider/screens/delivery_delivery_progress_screen.dart) | Delivery updates |
| [`lib/rider/screens/tabs/rider_earnings_tab.dart`](../lib/rider/screens/tabs/rider_earnings_tab.dart) | Earnings notification |

---

### Email Usage Examples

#### Example 1: Send Booking Confirmation
```dart
final emailService = EmailNotificationService.instance;

await emailService.sendBookingConfirmationEmail(
  toEmail: 'customer@example.com',
  customerName: 'Juan Dela Cruz',
  bookingId: 'BK123456',
  pickupAddress: '123 Main St, Manila',
  dropoffAddress: '456 Oak Ave, Quezon City',
  vehicleType: '4-Wheeler',
  fare: 1250.00,
  pickupDate: DateTime.now(),
);
```

#### Example 2: Send OTP
```dart
await emailService.sendOtpEmail(
  toEmail: 'user@example.com',
  name: 'Juan Dela Cruz',
  otp: '123456',
  type: 'registration',
);
```

---

### Testing Email Integration

1. **Test Email Sending**
   - Create a test function in any screen
   - Call `emailService.sendEmail()` with test data
   - Check recipient inbox

2. **Monitor in Firebase Console**
   - Go to Firebase Console → Extensions
   - Click on Mailgun extension
   - View logs and delivery status

3. **View Firestore Documents**
   - Firebase Console → Firestore Database → `mail` collection
   - See all sent emails with metadata

---

### Cost Summary

| Service | Cost |
|---------|------|
| Firebase Extensions | Free |
| Mailgun Free Tier | 5,000 emails/month |
| Mailgun Paid | $35/50,000 emails |

---

## Payment Gateway Integration Plan (Dragonpay)

### Why Dragonpay?

- **Philippines-based** payment gateway
- Supports multiple payment methods:
  - Credit/Debit Cards (Visa, Mastercard, JCB)
  - Online Banking (BDO, BPI, Metrobank, etc.)
  - E-wallets (GCash, PayMaya)
  - Over-the-counter (7-Eleven, MLhuillier, Cebuana)
  - QR payments
- Easy integration with REST API
- Webhook support for payment notifications

---

### Files to Create/Modify

#### 1. New Files to Create

| File | Purpose |
|------|---------|
| `lib/services/dragonpay_service.dart` | Dragonpay API integration service |
| `lib/models/payment_transaction_model.dart` | Payment transaction data model |
| `lib/screens/payment/payment_processing_screen.dart` | Payment processing/loading screen |
| `lib/screens/payment/payment_result_screen.dart` | Payment success/failure result screen |
| `lib/screens/payment/payment_method_selection_screen.dart` | Dragonpay payment method selection |

#### 2. Files to Modify

| File | Changes Required |
|------|-----------------|
| [`pubspec.yaml`](../pubspec.yaml) | Add `http: ^1.1.0` (already added) |
| [`lib/services/payment_service.dart`](../lib/services/payment_service.dart) | Add Dragonpay integration methods |
| [`lib/models/booking_model.dart`](../lib/models/booking_model.dart) | Add payment transaction fields |
| [`lib/screens/booking/booking_summary_screen.dart`](../lib/screens/booking/booking_summary_screen.dart) | Add Dragonpay payment option |
| [`lib/screens/delivery/delivery_completion_screen.dart`](../lib/screens/delivery/delivery_completion_screen.dart) | Add payment processing for tips |
| [`lib/rider/screens/tabs/rider_earnings_tab.dart`](../lib/rider/screens/tabs/rider_earnings_tab.dart) | Add payout request via Dragonpay |

---

### Dragonpay Integration Architecture

```
┌─────────────────┐
│   CitiMovers   │
│     App        │
└────────┬────────┘
         │
         │ 1. Initiate Payment
         │    (amount, description, etc.)
         ▼
┌─────────────────┐
│  Dragonpay      │
│  API Gateway   │
└────────┬────────┘
         │
         │ 2. Redirect to Dragonpay
         │    Payment Page
         ▼
┌─────────────────┐
│  Dragonpay     │
│  Payment Page  │
└────────┬────────┘
         │
         │ 3. User Completes Payment
         │
         ├─────────────┬─────────────┐
         │             │             │
         ▼             ▼             ▼
    Success      Cancelled    Failed
         │             │             │
         │ 4. Webhook   │             │
         │    to Firebase│             │
         │    Functions  │             │
         ▼             ▼             ▼
┌─────────────────────────────────────┐
│   Firebase Cloud Functions          │
│   - Process webhook               │
│   - Update Firestore              │
│   - Send email notification       │
└─────────────────────────────────────┘
         │
         │ 5. Return to App
         │    (via Deep Link)
         ▼
┌─────────────────┐
│ Payment Result │
│   Screen       │
└─────────────────┘
```

---

### Dragonpay Service Structure

#### DragonpayService Methods

| Method | Purpose |
|--------|---------|
| `initiatePayment()` | Start payment process, get payment URL |
| `getPaymentStatus()` | Check payment status by transaction ID |
| `cancelPayment()` | Cancel pending payment |
| `processWebhook()` | Handle Dragonpay webhook (Cloud Function) |
| `getPaymentMethods()` | Get available payment methods |

---

### Firestore Collections to Add

| Collection | Purpose |
|------------|---------|
| `payment_transactions` | Store all payment transactions |
| `dragonpay_webhooks` | Log all webhook events for debugging |

---

### Payment Transaction Model Fields

```dart
class PaymentTransactionModel {
  String transactionId;        // Dragonpay transaction ID
  String bookingId;           // Associated booking ID
  String userId;              // User who made payment
  double amount;             // Payment amount
  String currency;           // PHP
  String paymentMethod;       // Credit Card, GCash, etc.
  String status;             // pending, success, failed, cancelled
  DateTime createdAt;
  DateTime? completedAt;
  String? dragonpayTxnId;    // Dragonpay's transaction ID
  String? description;
  Map<String, dynamic>? metadata; // Additional data
}
```

---

### Payment Flow Implementation

#### Customer Booking Payment

1. **Booking Summary Screen** ([`lib/screens/booking/booking_summary_screen.dart`](../lib/screens/booking/booking_summary_screen.dart))
   - User selects "Pay with Dragonpay"
   - Call `DragonpayService.initiatePayment()`
   - Get Dragonpay payment URL
   - Redirect user to Dragonpay payment page

2. **Payment Processing Screen** ([`lib/screens/payment/payment_processing_screen.dart`](../lib/screens/payment/payment_processing_screen.dart))
   - Show loading animation
   - Display "Waiting for payment..."
   - Poll for payment status every 5 seconds (fallback)

3. **Dragonpay Payment Page** (External)
   - User selects payment method
   - User completes payment
   - Dragonpay sends webhook to Firebase Cloud Functions

4. **Cloud Function** (Backend)
   - Receive webhook from Dragonpay
   - Verify webhook signature
   - Update payment transaction status in Firestore
   - Update booking status to "paid"
   - Send email notification to user

5. **Return to App** (via Deep Link)
   - User clicks "Return to App" button
   - App opens `PaymentResultScreen`
   - Display success/failure message

6. **Payment Result Screen** ([`lib/screens/payment/payment_result_screen.dart`](../lib/screens/payment/payment_result_screen.dart))
   - Show payment status
   - Display transaction details
   - Provide "View Booking" button

---

#### Rider Payout

1. **Rider Earnings Tab** ([`lib/rider/screens/tabs/rider_earnings_tab.dart`](../lib/rider/screens/tabs/rider_earnings_tab.dart))
   - Rider requests payout
   - Enter payout amount
   - Select Dragonpay as payout method
   - Call `DragonpayService.initiatePayout()`

2. **Payout Processing**
   - Similar flow to customer payment
   - Funds transferred to rider's Dragonpay account
   - Rider receives notification

---

### Dragonpay API Endpoints

| Endpoint | Method | Purpose |
|----------|---------|---------|
| `/api/merchant/txnlite` | POST | Initiate payment |
| `/api/merchant/gettxnid` | GET | Get transaction status |
| `/api/merchant/canceltxn` | POST | Cancel transaction |
| `/api/merchant/getavailablechannels` | GET | Get payment channels |

---

### Firebase Cloud Functions for Dragonpay

#### Function 1: Process Dragonpay Webhook

**Purpose:** Receive and process payment status updates from Dragonpay

**Logic:**
1. Receive POST request from Dragonpay
2. Verify webhook signature (security)
3. Extract transaction details
4. Update `payment_transactions` collection
5. Update `bookings` collection status
6. Send email notification via EmailNotificationService
7. Send push notification to user

#### Function 2: Check Payment Status (Fallback)

**Purpose:** Polling fallback if webhook fails

**Logic:**
1. Called by app every 5 seconds during payment
2. Query Dragonpay API for transaction status
3. Return status to app
4. Update Firestore if status changed

---

### Deep Link Configuration

#### Android Configuration

File: `android/app/src/main/AndroidManifest.xml`

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data
    android:scheme="citimovers"
    android:host="payment"
    android:pathPrefix="/result" />
</intent-filter>
```

#### iOS Configuration

File: `ios/Runner/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>citimovers</string>
    </array>
  </dict>
</array>
```

---

### Flutter Deep Link Handling

File: `lib/main.dart`

```dart
// Add uni_links package to pubspec.yaml
import 'package:uni_links/uni_links.dart';

// In main()
await initUniLinks();

Future<void> initUniLinks() async {
  // Handle incoming links
  linkStream.listen((String? link) {
    if (link != null && link.contains('payment/result')) {
      // Parse payment result and navigate to PaymentResultScreen
      final uri = Uri.parse(link);
      final txnId = uri.queryParameters['txnId'];
      final status = uri.queryParameters['status'];
      // Navigate to result screen
    }
  });
}
```

---

### Dragonpay Configuration

#### Environment Variables

Store these in Firebase Cloud Functions config:

```bash
firebase functions:config:set dragonpay.merchant_id="YOUR_MERCHANT_ID"
firebase functions:config:set dragonpay.password="YOUR_PASSWORD"
firebase functions:config:set dragonpay.api_key="YOUR_API_KEY"
firebase functions:config:set dragonpay.webhook_secret="YOUR_WEBHOOK_SECRET"
```

---

## Payment Gateway Loopholes & Solutions

### Loophole 1: App Session Loss During Payment

**Problem:** User completes payment on Dragonpay website, but the app is closed, crashes, or loses session. When user returns to app, payment status is unknown.

**Solution:**
- Store pending payment transaction in Firestore before redirecting to Dragonpay
- Include transaction ID in deep link parameters
- On app launch, check for pending transactions in Firestore
- Query Dragonpay API to get current status
- Display correct payment result regardless of app state

---

### Loophole 2: Webhook Not Received or Delayed

**Problem:** Dragonpay webhook may fail to reach Firebase Cloud Functions due to network issues, server downtime, or Dragonpay delays.

**Solution:**
- Implement polling mechanism in app as fallback
- App checks payment status every 5 seconds while on payment processing screen
- If webhook is delayed, app will still get updated status via polling
- Store last known status in Firestore to avoid duplicate processing

---

### Loophole 3: Duplicate Webhook Processing

**Problem:** Dragonpay may send multiple webhooks for the same transaction, causing duplicate processing.

**Solution:**
- Store processed webhook IDs in Firestore
- Check if webhook ID already exists before processing
- Use Firestore transactions to ensure atomic updates
- Implement idempotent webhook processing logic

---

### Loophole 4: Payment Status Mismatch

**Problem:** App shows "Payment Failed" but Dragonpay shows "Success" (or vice versa) due to timing issues or caching.

**Solution:**
- Always query Dragonpay API as single source of truth
- Never rely solely on local app state
- Implement status reconciliation: Compare app status with Dragonpay status
- If mismatch found, query Dragonpay API and update Firestore
- Show "Verifying payment..." status until confirmed

---

### Loophole 5: User Cancels Payment After Timeout

**Problem:** Payment is completed on Dragonpay but user doesn't return to app. User later cancels or retries payment, causing double charge.

**Solution:**
- Store transaction state in Firestore
- Check if payment already completed before allowing new payment
- Show warning: "You have a pending payment. Please wait for confirmation."
- Implement payment locking mechanism: Prevent new payment if one is in progress

---

### Loophole 6: Man-in-the-Middle Attacks on Webhook

**Problem:** Attacker could send fake webhook requests to Firebase Cloud Functions to mark payments as successful.

**Solution:**
- Verify webhook signature using Dragonpay's secret key
- Validate all webhook parameters
- Cross-reference with Dragonpay API before updating status
- Implement IP whitelist for webhook endpoints
- Log all webhook events for audit

---

### Loophole 7: Payment Timeout Without Status Update

**Problem:** Payment is initiated but no status update received (webhook failed, polling stopped, app closed).

**Solution:**
- Implement background job to check pending payments
- Use Firebase Cloud Functions scheduled triggers (cron job)
- Check all transactions with "pending" status older than 15 minutes
- Query Dragonpay API for each pending transaction
- Update status accordingly
- Send notification to user if payment status changes

---

### Loophole 8: Race Condition Between Webhook and Polling

**Problem:** Webhook and polling both receive status update simultaneously, causing duplicate processing.

**Solution:**
- Use Firestore transactions with optimistic locking
- Check document version/timestamp before updating
- Implement "processing" flag to prevent concurrent updates
- Use Firestore's `runTransaction()` for atomic operations

---

### Loophole 9: User Manipulates Payment Amount

**Problem:** Attacker could modify payment amount in request before sending to Dragonpay.

**Solution:**
- Never trust client-side payment amount
- Calculate final amount on server (Cloud Functions)
- Validate amount matches booking fare
- Include checksum in payment request
- Dragonpay validates merchant signature

---

### Loophole 10: Payment for Cancelled/Expired Booking

**Problem:** User pays for a booking that was already cancelled or expired.

**Solution:**
- Validate booking status before initiating payment
- Check if booking is still "pending" or "awaiting_payment"
- Reject payment if booking is "cancelled" or "completed"
- Implement booking expiration: Auto-cancel unpaid bookings after 30 minutes

---

### Loophole 11: Refund Fraud

**Problem:** User claims payment failed but Dragonpay shows success, requesting refund.

**Solution:**
- Maintain complete audit trail of all payment events
- Store webhook timestamps, polling results, and API responses
- Cross-reference with Dragonpay transaction history
- Implement dispute resolution workflow
- Use Dragonpay's refund API with proper authorization

---

### Loophole 12: Deep Link Hijacking

**Problem:** Attacker could craft malicious deep link to show fake payment success.

**Solution:**
- Validate deep link parameters
- Query Dragonpay API to verify transaction
- Never trust deep link status alone
- Show transaction details from Firestore (single source of truth)
- Implement deep link signature verification

---

### Loophole 13: App Killed During Payment Processing

**Problem:** User force-kills app or system kills app during payment processing. No background task to check status.

**Solution:**
- Use Firebase Cloud Messaging (FCM) for status updates
- Send push notification when webhook is processed
- On app launch, check for pending transactions
- Implement Firebase Cloud Functions scheduled job for cleanup

---

### Loophole 14: Network Timeout During Payment Initiation

**Problem:** Payment is initiated on Dragonpay but app loses network before receiving payment URL.

**Solution:**
- Store transaction ID in local storage before initiating payment
- Implement retry mechanism with exponential backoff
- On app restart, check for incomplete transactions
- Allow user to resume payment from transaction history

---

### Loophole 15: Payment Method Not Supported

**Problem:** User selects payment method that is not available or has insufficient funds.

**Solution:**
- Query Dragonpay for available payment channels before showing options
- Display only available methods for the amount
- Show error message if payment method fails
- Allow user to retry with different method

---

### Loophole 16: Currency Mismatch

**Problem:** Payment initiated in wrong currency or amount conversion issues.

**Solution:**
- Always use PHP (Philippine Peso) as currency
- Validate amount format before sending to Dragonpay
- Display exact amount to user before payment
- Store original amount in Firestore for reference

---

### Loophole 17: Booking Modified During Payment

**Problem:** Booking details (fare, items) change while payment is in progress.

**Solution:**
- Lock booking when payment is initiated
- Prevent modifications to booking during payment
- If booking changes, invalidate payment and request new payment
- Show warning to user: "Please complete payment before modifying booking"

---

### Loophole 18: Multiple Concurrent Payments

**Problem:** User initiates multiple payments for the same booking simultaneously.

**Solution:**
- Implement payment locking mechanism
- Check for existing payment transaction for booking
- Allow only one active payment per booking
- Show error: "Payment already in progress"

---

### Loophole 19: Webhook Signature Verification Failure

**Problem:** Dragonpay webhook signature verification fails due to encoding or formatting issues.

**Solution:**
- Follow Dragonpay's signature algorithm exactly
- Test signature verification in development
- Log all webhook attempts for debugging
- Implement fallback: If signature fails, query Dragonpay API directly

---

### Loophole 20: Payment Status Not Persisted

**Problem:** Payment status is updated in memory but not persisted to Firestore before app crashes.

**Solution:**
- Always write to Firestore immediately after receiving webhook
- Use Firestore transactions for atomic updates
- Implement retry mechanism for failed writes
- Store payment status in multiple locations (transactions, bookings)

---

## Summary Checklist

### Email Integration (Mailgun)
- [ ] Install Firebase CLI
- [ ] Install Mailgun extension
- [ ] Configure Mailgun API key and domain
- [ ] Deploy Firebase extension
- [ ] Test email sending
- [ ] Monitor email delivery

### Payment Gateway (Dragonpay)
- [ ] Create Dragonpay merchant account
- [ ] Get Dragonpay API credentials
- [ ] Create DragonpayService
- [ ] Create payment transaction model
- [ ] Create payment screens (processing, result, method selection)
- [ ] Implement payment initiation flow
- [ ] Implement webhook Cloud Function
- [ ] Configure deep links (Android & iOS)
- [ ] Implement polling fallback
- [ ] Add payment status reconciliation
- [ ] Implement all security measures
- [ ] Test payment flow end-to-end
- [ ] Test all loopholes and edge cases
- [ ] Deploy Cloud Functions
- [ ] Monitor payment transactions

---

## Additional Resources

- **Mailgun Documentation:** https://documentation.mailgun.com
- **Dragonpay Documentation:** https://dragonpay.ph/docs/
- **Firebase Extensions:** https://firebase.google.com/docs/extensions
- **Firebase Cloud Functions:** https://firebase.google.com/docs/functions
- **Flutter Deep Links:** https://docs.flutter.dev/ui/navigation/deep-linking
