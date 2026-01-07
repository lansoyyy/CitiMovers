import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for Email Notification
class EmailNotificationModel {
  final String id;
  final String to;
  final String subject;
  final String htmlBody;
  final String? textBody;
  final String? templateId; // For using email templates
  final Map<String, dynamic>? templateData; // Data for template variables
  final String
      type; // 'booking', 'payment', 'verification', 'promotional', 'system'
  final String? referenceId; // booking ID, payment ID, etc.
  final bool isSent;
  final DateTime? sentAt;
  final String? errorMessage;
  final DateTime createdAt;

  EmailNotificationModel({
    required this.id,
    required this.to,
    required this.subject,
    required this.htmlBody,
    this.textBody,
    this.templateId,
    this.templateData,
    required this.type,
    this.referenceId,
    this.isSent = false,
    this.sentAt,
    this.errorMessage,
    required this.createdAt,
  });

  factory EmailNotificationModel.fromMap(Map<String, dynamic> map) {
    return EmailNotificationModel(
      id: map['id'] ?? '',
      to: map['to'] ?? '',
      subject: map['subject'] ?? '',
      htmlBody: map['htmlBody'] ?? '',
      textBody: map['textBody'],
      templateId: map['templateId'],
      templateData: map['templateData'] as Map<String, dynamic>?,
      type: map['type'] ?? 'system',
      referenceId: map['referenceId'],
      isSent: map['isSent'] ?? false,
      sentAt: map['sentAt'] != null
          ? (map['sentAt'] is Timestamp
              ? (map['sentAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['sentAt'] as int))
          : null,
      errorMessage: map['errorMessage'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'to': to,
      'subject': subject,
      'htmlBody': htmlBody,
      'textBody': textBody,
      'templateId': templateId,
      'templateData': templateData,
      'type': type,
      'referenceId': referenceId,
      'isSent': isSent,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'errorMessage': errorMessage,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Service for managing Email Notifications
///
/// NOTE: This service uses Firebase Extensions + Mailgun for email sending.
/// Emails are written to the 'mail' collection in Firestore, which triggers
/// the Mailgun extension to send the actual email.
///
/// Setup required:
/// 1. Install Firebase CLI: npm install -g firebase-tools
/// 2. Install Mailgun extension: firebase extensions:install mailgun/send-email
/// 3. Configure with your Mailgun API key and domain
/// 4. Deploy: firebase deploy --only extensions
class EmailNotificationService {
  static EmailNotificationService? _instance;
  static EmailNotificationService get instance {
    _instance ??= EmailNotificationService._internal();
    return _instance!;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'mail'; // Firebase Extension collection

  EmailNotificationService._internal();

  /// Send email notification using Firebase Extensions + Mailgun
  ///
  /// This writes to the 'mail' collection which triggers the Mailgun extension
  /// to send the actual email. No Cloud Functions code needed.
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlBody,
    String? textBody,
    String? templateId,
    Map<String, dynamic>? templateData,
    required String type,
    String? referenceId,
  }) async {
    try {
      // Write to 'mail' collection for Firebase Extension to process
      await _firestore.collection(_collection).add({
        'to': to,
        'message': {
          'subject': subject,
          'html': htmlBody,
          if (textBody != null) 'text': textBody,
        },
        // Optional: Store metadata for tracking
        'metadata': {
          'type': type,
          if (referenceId != null) 'referenceId': referenceId,
          if (templateId != null) 'templateId': templateId,
          if (templateData != null) 'templateData': templateData,
          'createdAt': DateTime.now().toIso8601String(),
        },
      });

      return true;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  /// Send booking confirmation email to customer
  Future<bool> sendBookingConfirmationEmail({
    required String toEmail,
    required String customerName,
    required String bookingId,
    required String pickupAddress,
    required String dropoffAddress,
    required String vehicleType,
    required double fare,
    required DateTime pickupDate,
  }) async {
    final subject = 'Booking Confirmed - CitiMovers';
    final htmlBody = _buildBookingConfirmationHtml(
      customerName: customerName,
      bookingId: bookingId,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      vehicleType: vehicleType,
      fare: fare,
      pickupDate: pickupDate,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'booking',
      referenceId: bookingId,
    );
  }

  /// Send rider assignment email to customer
  Future<bool> sendRiderAssignedEmail({
    required String toEmail,
    required String customerName,
    required String bookingId,
    required String riderName,
    required String? riderPhone,
    required String? vehicleType,
    required String? vehiclePlateNumber,
  }) async {
    final subject = 'Rider Assigned - CitiMovers';
    final htmlBody = _buildRiderAssignedHtml(
      customerName: customerName,
      bookingId: bookingId,
      riderName: riderName,
      riderPhone: riderPhone,
      vehicleType: vehicleType,
      vehiclePlateNumber: vehiclePlateNumber,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'booking',
      referenceId: bookingId,
    );
  }

  /// Send delivery completed email to customer
  Future<bool> sendDeliveryCompletedEmail({
    required String toEmail,
    required String customerName,
    required String bookingId,
    required double fare,
  }) async {
    final subject = 'Delivery Completed - CitiMovers';
    final htmlBody = _buildDeliveryCompletedHtml(
      customerName: customerName,
      bookingId: bookingId,
      fare: fare,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'booking',
      referenceId: bookingId,
    );
  }

  /// Send OTP verification email
  Future<bool> sendOtpEmail({
    required String toEmail,
    required String name,
    required String otp,
    required String type, // 'registration', 'login', 'reset_password'
  }) async {
    final subject = 'Your Verification Code - CitiMovers';
    final htmlBody = _buildOtpHtml(
      name: name,
      otp: otp,
      type: type,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'verification',
    );
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail({
    required String toEmail,
    required String name,
    required String resetLink,
  }) async {
    final subject = 'Reset Your Password - CitiMovers';
    final htmlBody = _buildPasswordResetHtml(
      name: name,
      resetLink: resetLink,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'verification',
    );
  }

  /// Send payment confirmation email
  Future<bool> sendPaymentConfirmationEmail({
    required String toEmail,
    required String name,
    required String paymentId,
    required double amount,
    required String paymentMethod,
  }) async {
    final subject = 'Payment Successful - CitiMovers';
    final htmlBody = _buildPaymentConfirmationHtml(
      name: name,
      paymentId: paymentId,
      amount: amount,
      paymentMethod: paymentMethod,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'payment',
      referenceId: paymentId,
    );
  }

  /// Send wallet top-up confirmation email
  Future<bool> sendWalletTopUpEmail({
    required String toEmail,
    required String name,
    required double amount,
    required double newBalance,
  }) async {
    final subject = 'Wallet Top-up Successful - CitiMovers';
    final htmlBody = _buildWalletTopUpHtml(
      name: name,
      amount: amount,
      newBalance: newBalance,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'payment',
    );
  }

  /// Send earning notification email to rider
  Future<bool> sendEarningNotificationEmail({
    required String toEmail,
    required String riderName,
    required String bookingId,
    required double earning,
    required double totalEarnings,
  }) async {
    final subject = 'New Earning Added - CitiMovers Rider';
    final htmlBody = _buildEarningNotificationHtml(
      riderName: riderName,
      bookingId: bookingId,
      earning: earning,
      totalEarnings: totalEarnings,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'payment',
      referenceId: bookingId,
    );
  }

  /// Send promotional email
  Future<bool> sendPromotionalEmail({
    required String toEmail,
    required String name,
    required String title,
    required String message,
    String? promoCode,
    String? imageUrl,
  }) async {
    final subject = '$title - CitiMovers';
    final htmlBody = _buildPromotionalHtml(
      name: name,
      title: title,
      message: message,
      promoCode: promoCode,
      imageUrl: imageUrl,
    );

    return sendEmail(
      to: toEmail,
      subject: subject,
      htmlBody: htmlBody,
      type: 'promotional',
    );
  }

  // HTML Template Builders

  String _buildBookingConfirmationHtml({
    required String customerName,
    required String bookingId,
    required String pickupAddress,
    required String dropoffAddress,
    required String vehicleType,
    required double fare,
    required DateTime pickupDate,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Booking Confirmed - CitiMovers</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #e63946, #d62828); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label { font-weight: bold; color: #666; }
    .detail-value { color: #333; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
    .button { display: inline-block; padding: 12px 30px; background: #e63946; color: white; text-decoration: none; border-radius: 5px; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Booking Confirmed! 🎉</h1>
    </div>
    <div class="content">
      <p>Dear $customerName,</p>
      <p>Your booking has been confirmed successfully. Here are your booking details:</p>
      
      <div class="details">
        <div class="detail-row">
          <span class="detail-label">Booking ID:</span>
          <span class="detail-value">$bookingId</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Pickup:</span>
          <span class="detail-value">$pickupAddress</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Drop-off:</span>
          <span class="detail-value">$dropoffAddress</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Vehicle:</span>
          <span class="detail-value">$vehicleType</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Pickup Date:</span>
          <span class="detail-value">${_formatDate(pickupDate)}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Estimated Fare:</span>
          <span class="detail-value">₱${fare.toStringAsFixed(2)}</span>
        </div>
      </div>
      
      <p>You will receive another email when a rider is assigned to your booking.</p>
      
      <div class="footer">
        <p>Thank you for choosing CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildRiderAssignedHtml({
    required String customerName,
    required String bookingId,
    required String riderName,
    String? riderPhone,
    String? vehicleType,
    String? vehiclePlateNumber,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Rider Assigned - CitiMovers</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #e63946, #d62828); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label { font-weight: bold; color: #666; }
    .detail-value { color: #333; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Rider Assigned! 🚚</h1>
    </div>
    <div class="content">
      <p>Dear $customerName,</p>
      <p>A rider has been assigned to your booking. Here are the details:</p>
      
      <div class="details">
        <div class="detail-row">
          <span class="detail-label">Booking ID:</span>
          <span class="detail-value">$bookingId</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Rider Name:</span>
          <span class="detail-value">$riderName</span>
        </div>
        ${riderPhone != null ? '''
        <div class="detail-row">
          <span class="detail-label">Rider Phone:</span>
          <span class="detail-value">$riderPhone</span>
        </div>
        ''' : ''}
        ${vehicleType != null ? '''
        <div class="detail-row">
          <span class="detail-label">Vehicle:</span>
          <span class="detail-value">$vehicleType</span>
        </div>
        ''' : ''}
        ${vehiclePlateNumber != null ? '''
        <div class="detail-row">
          <span class="detail-label">Plate Number:</span>
          <span class="detail-value">$vehiclePlateNumber</span>
        </div>
        ''' : ''}
      </div>
      
      <p>Your rider is on the way to the pickup location. You can track your delivery in the app.</p>
      
      <div class="footer">
        <p>Thank you for choosing CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildDeliveryCompletedHtml({
    required String customerName,
    required String bookingId,
    required double fare,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Delivery Completed - CitiMovers</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label { font-weight: bold; color: #666; }
    .detail-value { color: #333; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
    .button { display: inline-block; padding: 12px 30px; background: #28a745; color: white; text-decoration: none; border-radius: 5px; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Delivery Completed! ✅</h1>
    </div>
    <div class="content">
      <p>Dear $customerName,</p>
      <p>Your delivery has been completed successfully. Thank you for using CitiMovers!</p>
      
      <div class="details">
        <div class="detail-row">
          <span class="detail-label">Booking ID:</span>
          <span class="detail-value">$bookingId</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Total Fare:</span>
          <span class="detail-value">₱${fare.toStringAsFixed(2)}</span>
        </div>
      </div>
      
      <p>We hope you had a great experience. Please rate your rider in the app!</p>
      
      <div class="footer">
        <p>Thank you for choosing CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildOtpHtml({
    required String name,
    required String otp,
    required String type,
  }) {
    String typeText;
    switch (type) {
      case 'registration':
        typeText = 'complete your registration';
        break;
      case 'login':
        typeText = 'log in to your account';
        break;
      case 'reset_password':
        typeText = 'reset your password';
        break;
      default:
        typeText = 'verify your account';
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verification Code - CitiMovers</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #e63946, #d62828); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; text-align: center; }
    .otp-code { font-size: 36px; font-weight: bold; color: #e63946; letter-spacing: 5px; margin: 30px 0; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
    .warning { background: #fff3cd; color: #856404; padding: 15px; border-radius: 5px; margin-top: 20px; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Your Verification Code</h1>
    </div>
    <div class="content">
      <p>Dear $name,</p>
      <p>Use the following code to $typeText:</p>
      
      <div class="otp-code">$otp</div>
      
      <p>This code will expire in 10 minutes.</p>
      
      <div class="warning">
        <strong>⚠️ Security Notice:</strong> Never share this code with anyone. If you didn't request this code, please ignore this email.
      </div>
      
      <div class="footer">
        <p>Thank you for choosing CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildPasswordResetHtml({
    required String name,
    required String resetLink,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Your Password - CitiMovers</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #e63946, #d62828); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; text-align: center; }
    .button { display: inline-block; padding: 12px 30px; background: #e63946; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
    .warning { background: #fff3cd; color: #856404; padding: 15px; border-radius: 5px; margin-top: 20px; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Reset Your Password</h1>
    </div>
    <div class="content">
      <p>Dear $name,</p>
      <p>We received a request to reset your password. Click the button below to create a new password:</p>
      
      <a href="$resetLink" class="button">Reset Password</a>
      
      <p>This link will expire in 1 hour.</p>
      
      <div class="warning">
        <strong>⚠️ Security Notice:</strong> If you didn't request this password reset, please ignore this email and your password will remain unchanged.
      </div>
      
      <div class="footer">
        <p>Thank you for choosing CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildPaymentConfirmationHtml({
    required String name,
    required String paymentId,
    required double amount,
    required String paymentMethod,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Successful - CitiMovers</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label { font-weight: bold; color: #666; }
    .detail-value { color: #333; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Payment Successful! ✅</h1>
    </div>
    <div class="content">
      <p>Dear $name,</p>
      <p>Your payment has been processed successfully. Here are the details:</p>
      
      <div class="details">
        <div class="detail-row">
          <span class="detail-label">Payment ID:</span>
          <span class="detail-value">$paymentId</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Amount:</span>
          <span class="detail-value">₱${amount.toStringAsFixed(2)}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Payment Method:</span>
          <span class="detail-value">$paymentMethod</span>
        </div>
      </div>
      
      <div class="footer">
        <p>Thank you for choosing CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildWalletTopUpHtml({
    required String name,
    required double amount,
    required double newBalance,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Wallet Top-up Successful - CitiMovers</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label { font-weight: bold; color: #666; }
    .detail-value { color: #333; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Wallet Top-up Successful! 💰</h1>
    </div>
    <div class="content">
      <p>Dear $name,</p>
      <p>Your wallet has been topped up successfully. Here are the details:</p>
      
      <div class="details">
        <div class="detail-row">
          <span class="detail-label">Top-up Amount:</span>
          <span class="detail-value">₱${amount.toStringAsFixed(2)}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">New Balance:</span>
          <span class="detail-value">₱${newBalance.toStringAsFixed(2)}</span>
        </div>
      </div>
      
      <p>You can now use your wallet balance for payments.</p>
      
      <div class="footer">
        <p>Thank you for choosing CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildEarningNotificationHtml({
    required String riderName,
    required String bookingId,
    required double earning,
    required double totalEarnings,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New Earning Added - CitiMovers Rider</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label { font-weight: bold; color: #666; }
    .detail-value { color: #333; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>New Earning Added! 🎉</h1>
    </div>
    <div class="content">
      <p>Dear $riderName,</p>
      <p>Great job! You've completed another delivery. Here are your earning details:</p>
      
      <div class="details">
        <div class="detail-row">
          <span class="detail-label">Booking ID:</span>
          <span class="detail-value">$bookingId</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Earning:</span>
          <span class="detail-value">₱${earning.toStringAsFixed(2)}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Total Earnings:</span>
          <span class="detail-value">₱${totalEarnings.toStringAsFixed(2)}</span>
        </div>
      </div>
      
      <p>Keep up the great work!</p>
      
      <div class="footer">
        <p>Thank you for being part of CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildPromotionalHtml({
    required String name,
    required String title,
    required String message,
    String? promoCode,
    String? imageUrl,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title - CitiMovers</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #e63946, #d62828); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; }
    .promo-code { background: #e63946; color: white; font-size: 24px; font-weight: bold; padding: 15px 30px; border-radius: 5px; display: inline-block; margin: 20px 0; letter-spacing: 2px; }
    .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
    .image { max-width: 100%; border-radius: 8px; margin: 20px 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>$title</h1>
    </div>
    <div class="content">
      <p>Dear $name,</p>
      <p>$message</p>
      ${imageUrl != null ? '<img src="$imageUrl" alt="Promo" class="image">' : ''}
      ${promoCode != null ? '''
      <p style="text-align: center;">Use this promo code:</p>
      <div style="text-align: center;">
        <div class="promo-code">$promoCode</div>
      </div>
      ''' : ''}
      
      <div class="footer">
        <p>Thank you for choosing CitiMovers!</p>
        <p>Need help? Contact us at support@citimovers.com</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
