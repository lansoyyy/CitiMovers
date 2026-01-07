# CitiMovers - Simple Email Integration Guide

## Recommended Solution: Firebase Extensions + Mailgun

For **simple email sending** without writing Cloud Functions code, use **Firebase Extensions with Mailgun**.

---

## Why This Approach?

| Benefit | Description |
|---------|-------------|
| ✅ **No Code Required** | No Cloud Functions to write or maintain |
| ✅ **Quick Setup** | Install and configure in minutes |
| ✅ **Secure** | API keys stored in Firebase, not in Flutter app |
| ✅ **Scalable** | Handles thousands of emails automatically |
| ✅ **Reliable** | Managed by Firebase and Mailgun |

---

## Prerequisites

1. **Firebase Project** - Already set up for CitiMovers
2. **Mailgun Account** - Sign up at [mailgun.com](https://mailgun.com)
3. **Firebase CLI** - Install on your development machine

---

## Step-by-Step Setup

### Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase

```bash
firebase login
```

### Step 3: Navigate to Project Directory

```bash
cd "d:/Flutter Projects/citimovers"
```

### Step 4: Install Mailgun Extension

```bash
firebase extensions:install mailgun/send-email --project=your-project-id
```

Replace `your-project-id` with your actual Firebase project ID.

### Step 5: Configure the Extension

When prompted, provide:

| Parameter | Value |
|-----------|-------|
| **Mailgun API Key** | Your Mailgun API key (from mailgun.com) |
| **Mailgun Domain** | Your Mailgun domain (e.g., `mg.yourdomain.com`) |
| **Default Sender Email** | `noreply@citimovers.com` |
| **Default Sender Name** | `CitiMovers` |

### Step 6: Deploy the Extension

```bash
firebase deploy --only extensions
```

---

## How to Send Emails from Flutter

### 1. Add Cloud Functions Package

Add to [`pubspec.yaml`](../pubspec.yaml):

```yaml
dependencies:
  cloud_functions: ^4.0.0
```

Run: `flutter pub get`

### 2. Update EmailNotificationService

The extension works by writing to a Firestore collection named `mail`. Update [`lib/services/email_notification_service.dart`](../lib/services/email_notification_service.dart):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a simple email using Firebase Extensions + Mailgun
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
    String? textContent,
  }) async {
    try {
      await _firestore.collection('mail').add({
        'to': to,
        'message': {
          'subject': subject,
          'html': htmlContent,
          if (textContent != null) 'text': textContent,
        },
      });
      return true;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  /// Send booking confirmation email
  Future<bool> sendBookingConfirmation({
    required String email,
    required String customerName,
    required String bookingId,
    required String pickupLocation,
    required String dropoffLocation,
    required String vehicleType,
    required double fare,
  }) async {
    final html = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #4CAF50;">Booking Confirmed!</h2>
        <p>Hi <strong>$customerName</strong>,</p>
        <p>Your booking has been confirmed. Here are the details:</p>
        <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
          <tr>
            <td style="padding: 10px; border: 1px solid #ddd;"><strong>Booking ID:</strong></td>
            <td style="padding: 10px; border: 1px solid #ddd;">$bookingId</td>
          </tr>
          <tr>
            <td style="padding: 10px; border: 1px solid #ddd;"><strong>Pickup:</strong></td>
            <td style="padding: 10px; border: 1px solid #ddd;">$pickupLocation</td>
          </tr>
          <tr>
            <td style="padding: 10px; border: 1px solid #ddd;"><strong>Dropoff:</strong></td>
            <td style="padding: 10px; border: 1px solid #ddd;">$dropoffLocation</td>
          </tr>
          <tr>
            <td style="padding: 10px; border: 1px solid #ddd;"><strong>Vehicle:</strong></td>
            <td style="padding: 10px; border: 1px solid #ddd;">$vehicleType</td>
          </tr>
          <tr>
            <td style="padding: 10px; border: 1px solid #ddd;"><strong>Total Fare:</strong></td>
            <td style="padding: 10px; border: 1px solid #ddd;">₱$fare.toStringAsFixed(2)}</td>
          </tr>
        </table>
        <p>Thank you for choosing CitiMovers!</p>
        <p style="color: #666; font-size: 12px;">© 2025 CitiMovers. All rights reserved.</p>
      </div>
    ''';

    return sendEmail(
      to: email,
      subject: 'Booking Confirmed - #$bookingId',
      htmlContent: html,
    );
  }

  /// Send OTP email
  Future<bool> sendOtpEmail({
    required String email,
    required String otp,
  }) async {
    final html = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; text-align: center;">
        <h2 style="color: #4CAF50;">Your Verification Code</h2>
        <p>Use the following code to verify your account:</p>
        <div style="background: #f5f5f5; padding: 20px; margin: 20px 0; border-radius: 8px;">
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px;">$otp</span>
        </div>
        <p style="color: #666;">This code will expire in 5 minutes.</p>
        <p style="color: #666; font-size: 12px;">If you didn't request this code, please ignore this email.</p>
        <p style="color: #666; font-size: 12px;">© 2025 CitiMovers. All rights reserved.</p>
      </div>
    ''';

    return sendEmail(
      to: email,
      subject: 'Your Verification Code',
      htmlContent: html,
    );
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail({
    required String email,
    required String resetLink,
  }) async {
    final html = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; text-align: center;">
        <h2 style="color: #4CAF50;">Reset Your Password</h2>
        <p>We received a request to reset your password. Click the button below to create a new password:</p>
        <div style="margin: 30px 0;">
          <a href="$resetLink" style="background: #4CAF50; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">Reset Password</a>
        </div>
        <p style="color: #666;">This link will expire in 1 hour.</p>
        <p style="color: #666; font-size: 12px;">If you didn't request this, please ignore this email.</p>
        <p style="color: #666; font-size: 12px;">© 2025 CitiMovers. All rights reserved.</p>
      </div>
    ''';

    return sendEmail(
      to: email,
      subject: 'Reset Your Password',
      htmlContent: html,
    );
  }

  /// Send delivery update email
  Future<bool> sendDeliveryUpdate({
    required String email,
    required String customerName,
    required String bookingId,
    required String status,
    required String message,
  }) async {
    final html = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #4CAF50;">Delivery Update</h2>
        <p>Hi <strong>$customerName</strong>,</p>
        <p>Your delivery status has been updated:</p>
        <div style="background: #f5f5f5; padding: 15px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #4CAF50;">
          <strong>$status</strong><br>
          $message
        </div>
        <p style="color: #666; font-size: 12px;">Booking ID: $bookingId</p>
        <p style="color: #666; font-size: 12px;">© 2025 CitiMovers. All rights reserved.</p>
      </div>
    ''';

    return sendEmail(
      to: email,
      subject: 'Delivery Update - #$bookingId',
      htmlContent: html,
    );
  }
}
```

---

## Usage Examples

### Example 1: Send Booking Confirmation

```dart
final emailService = EmailNotificationService();

await emailService.sendBookingConfirmation(
  email: 'customer@example.com',
  customerName: 'Juan Dela Cruz',
  bookingId: 'BK123456',
  pickupLocation: '123 Main St, Manila',
  dropoffLocation: '456 Oak Ave, Quezon City',
  vehicleType: '4-Wheeler',
  fare: 1250.00,
);
```

### Example 2: Send OTP

```dart
await emailService.sendOtpEmail(
  email: 'user@example.com',
  otp: '123456',
);
```

### Example 3: Send Delivery Update

```dart
await emailService.sendDeliveryUpdate(
  email: 'customer@example.com',
  customerName: 'Juan Dela Cruz',
  bookingId: 'BK123456',
  status: 'In Transit',
  message: 'Your driver is on the way to the delivery location.',
);
```

---

## Testing

### Test Email Sending

1. Create a test function in your app:

```dart
Future<void> testEmail() async {
  final emailService = EmailNotificationService();
  
  final success = await emailService.sendEmail(
    to: 'your-test-email@example.com',
    subject: 'Test Email from CitiMovers',
    htmlContent: '<h1>Test Successful!</h1><p>This is a test email.</p>',
  );
  
  print('Email sent: $success');
}
```

2. Call this function from a button or debug menu

---

## Monitoring

### View Email Logs

1. Go to Firebase Console
2. Navigate to **Extensions** section
3. Click on **Mailgun Send Email** extension
4. View logs and delivery status

### View Firestore Documents

Sent emails are stored in the `mail` collection:

```javascript
// View in Firebase Console → Firestore Database → mail collection
```

---

## Cost

| Service | Cost |
|---------|------|
| **Firebase Extension** | Free (included with Firebase) |
| **Mailgun** | Free: 5,000 emails/month<br>Paid: $35/50K emails |
| **Total** | Free for up to 5,000 emails/month |

---

## Troubleshooting

### Email Not Sending

1. Check Firebase Extensions logs
2. Verify Mailgun API key is correct
3. Verify Mailgun domain is verified
4. Check Firestore rules allow writing to `mail` collection

### API Key Issues

```bash
# Reconfigure extension with new API key
firebase extensions:configure mailgun/send-email
```

---

## Security Notes

✅ **API keys stored in Firebase** - Never exposed in Flutter app
✅ **Firestore security rules** - Control who can send emails
✅ **Rate limiting** - Mailgun automatically handles abuse

---

## Next Steps

1. ✅ Install Firebase CLI
2. ✅ Sign up for Mailgun
3. ✅ Install Firebase Extension
4. ✅ Update `EmailNotificationService`
5. ✅ Add `cloud_functions` to `pubspec.yaml`
6. ✅ Test email sending

---

## Support

- **Mailgun Docs**: https://documentation.mailgun.com
- **Firebase Extensions**: https://firebase.google.com/docs/extensions
- **Firebase Support**: https://firebase.google.com/support
