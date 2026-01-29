# EmailJS Template Configuration Guide
**For CitiMovers Email Verification**

---

## Overview

This guide provides the EmailJS template configuration required for the email verification feature implemented in [`lib/services/auth_service.dart`](lib/services/auth_service.dart:160).

---

## Required Template Parameters

The email verification system sends the following parameters to your EmailJS template:

| Parameter | Type | Description | Example |
|------------|------|-------------|----------|
| `otp_code` | String | The 6-digit verification code | `123456` |
| `expiry_minutes` | String | Time until code expires | `5` |
| `to_email` | String | Recipient email address | `user@example.com` |
| `subject` | String | Email subject | `CitiMovers Email Verification Code` |
| `from_email` | String | Sender email (from config) | `noreply@citimovers.com` |
| `from_name` | String | Sender name (from config) | `CitiMovers` |

---

## EmailJS Template Example

Create a new email template in your EmailJS dashboard with the following structure:

### HTML Template
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Verification - CitiMovers</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f4f4f4;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .header {
            background: linear-gradient(135deg, #e63946 0%, #dc2626 100%);
            padding: 30px;
            text-align: center;
        }
        .logo {
            font-size: 28px;
            font-weight: bold;
            color: #ffffff;
            margin: 0;
        }
        .content {
            padding: 40px 30px;
        }
        .greeting {
            font-size: 18px;
            color: #1f2937;
            margin-bottom: 20px;
        }
        .message {
            font-size: 16px;
            color: #4b5563;
            line-height: 1.6;
            margin-bottom: 30px;
        }
        .otp-container {
            background: linear-gradient(135deg, #fef3c7 0%, #fcd34d 100%);
            border: 2px dashed #f59e0b;
            border-radius: 10px;
            padding: 25px;
            text-align: center;
            margin: 30px 0;
        }
        .otp-label {
            font-size: 14px;
            color: #92400e;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .otp-code {
            font-size: 36px;
            font-weight: bold;
            color: #92400e;
            letter-spacing: 5px;
            margin: 0;
        }
        .expiry {
            font-size: 14px;
            color: #dc2626;
            text-align: center;
            margin-top: 20px;
        }
        .warning {
            background-color: #fef2f2;
            border-left: 4px solid #dc2626;
            padding: 15px;
            margin: 20px 0;
            font-size: 14px;
            color: #991b1b;
        }
        .footer {
            background-color: #f9fafb;
            padding: 20px 30px;
            text-align: center;
            font-size: 12px;
            color: #6b7280;
        }
        .footer a {
            color: #dc2626;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="logo">🚚 CitiMovers</h1>
        </div>
        <div class="content">
            <p class="greeting">Hello,</p>
            <p class="message">
                Thank you for choosing CitiMovers! To complete your email verification, 
                please use the verification code below:
            </p>
            <div class="otp-container">
                <div class="otp-label">Verification Code</div>
                <div class="otp-code">{{otp_code}}</div>
            </div>
            <p class="expiry">
                ⏰ This code will expire in <strong>{{expiry_minutes}} minutes</strong>
            </p>
            <div class="warning">
                <strong>⚠️ Security Notice:</strong><br>
                Never share this code with anyone. CitiMovers will never ask for your 
                verification code via phone or email. If you didn't request this code, 
                please ignore this email.
            </div>
        </div>
        <div class="footer">
            <p>
                Need help? Contact us at <a href="mailto:support@citimovers.com">support@citimovers.com</a>
            </p>
            <p>
                © 2026 CitiMovers. All rights reserved.<br>
                This is an automated email, please do not reply.
            </p>
        </div>
    </div>
</body>
</html>
```

---

## EmailJS Configuration Steps

### 1. Create Email Service
1. Log in to [EmailJS Dashboard](https://www.emailjs.com/)
2. Go to **Email Services** → **Add New Service**
3. Choose your email provider (Gmail, Outlook, etc.)
4. Enter your SMTP credentials
5. Click **Add Service**

### 2. Create Email Template
1. Go to **Email Templates** → **Create New Template**
2. Enter template name: `email-verification`
3. Paste the HTML template above
4. Click **Save**

### 3. Configure Template Parameters
1. In the template editor, identify the variables:
   - `{{otp_code}}` - Replace with your verification code variable
   - `{{expiry_minutes}}` - Replace with your expiry minutes variable
   - `{{to_email}}` - Replace with recipient email variable

2. EmailJS will automatically map template parameters to these variables

### 4. Update App Configuration
Ensure your [`lib/config/integrations_config.dart`](lib/config/integrations_config.dart) has correct values:

```dart
class IntegrationsConfig {
  // EmailJS Configuration
  static const String emailJsServiceId = 'YOUR_SERVICE_ID';
  static const String emailJsTemplateId = 'email-verification';
  static const String emailJsPublicKey = 'YOUR_PUBLIC_KEY';
  static const String emailJsAccessToken = 'YOUR_ACCESS_TOKEN'; // Optional
  
  static const String reportSenderEmail = 'noreply@citimovers.com';
  static const String reportSenderName = 'CitiMovers';
}
```

---

## Testing the Email Verification Flow

### Test Steps
1. **Start the app** and navigate to signup/login
2. **Enter an email address** and request verification
3. **Check the email inbox** for the verification email
4. **Enter the OTP code** from the email
5. **Verify successful verification**

### Expected Behavior
- Email should arrive within 10-30 seconds
- Email should contain a 6-digit code
- Code should expire after 5 minutes
- After 3 failed attempts, verification should be blocked
- Rate limiting should prevent more than 3 requests per 15 minutes

### Troubleshooting

| Issue | Solution |
|--------|----------|
| Email not received | Check spam folder, verify EmailJS service is active |
| Code doesn't work | Ensure code is entered correctly (6 digits) |
| Code expired | Request a new verification code |
| Too many requests | Wait 15 minutes before requesting again |

---

## Security Best Practices

### For Production
1. **Use SPF/DKIM records** for your email domain
2. **Monitor email delivery rates** to avoid being flagged as spam
3. **Implement email bounce handling** for invalid addresses
4. **Log all verification attempts** for security monitoring
5. **Consider CAPTCHA** for signup to prevent abuse

### Rate Limits
The implemented rate limits are:
- **OTP Requests:** Max 3 per 15 minutes per phone number
- **Email Verification:** Max 3 per 15 minutes per email address
- **Failed Attempts:** Max 3 attempts per OTP code

---

## Related Files

- [`lib/services/auth_service.dart`](lib/services/auth_service.dart:160) - Email verification implementation
- [`lib/services/otp_service.dart`](lib/services/otp_service.dart:1) - SMS OTP implementation
- [`lib/services/emailjs_service.dart`](lib/services/emailjs_service.dart:1) - EmailJS service wrapper
- [`lib/config/integrations_config.dart`](lib/config/integrations_config.dart:1) - Configuration

---

**Guide Created By:** Code Review System  
**Guide Version:** 1.0  
**Last Updated:** 2026-01-29
