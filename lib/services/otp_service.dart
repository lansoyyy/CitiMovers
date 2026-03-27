import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OtpService {
  static const int _otpExpiryMinutes = 5; // OTP expires after 5 minutes
  static const int _maxAttempts = 3; // Maximum failed attempts before blocking

  // Semaphore SMS API credentials
  static const String _semaphoreApiKey = '82fc33050497dd752b5d0ea2a94ed123';
  static const String _semaphoreSenderName = 'Citimovers';
  static const String _semaphoreEndpoint =
      'https://api.semaphore.co/api/v4/messages';

  // ---------------------------------------------------------------------------
  // Demo / Play Store review accounts
  // These accounts bypass real SMS sending and OTP validation so that app
  // store reviewers can log in without receiving a real SMS.
  // ---------------------------------------------------------------------------
  static const String _demoCustomerPhone = '+639639530423';
  // Demo driver login number (Play Store reviewer uses this to log in)
  static const String _demoDriverPhone = '+639090104355';
  static const String _demoOtp = '123456';

  static bool _isDemoAccount(String normalizedPhone) {
    return normalizedPhone == _demoCustomerPhone ||
        normalizedPhone == _demoDriverPhone;
  }

  // ---------------------------------------------------------------------------

  /// Generate a random 6-digit OTP
  static String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Normalize phone number to +63 format (used as Firestore key)
  static String _normalizePhoneNumber(String phoneNumber) {
    String normalized = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');

    if (!normalized.startsWith('+')) {
      if (normalized.startsWith('0')) {
        normalized = normalized.substring(1);
      }
      normalized = '+63$normalized';
    }

    return normalized;
  }

  /// Convert +63XXXXXXXXX to 09XXXXXXXXX for Semaphore
  static String _toSemaphoreFormat(String e164Number) {
    if (e164Number.startsWith('+63')) {
      return '0${e164Number.substring(3)}';
    }
    if (e164Number.startsWith('63') && e164Number.length == 12) {
      return '0${e164Number.substring(2)}';
    }
    return e164Number;
  }

  /// Send OTP SMS via Semaphore
  static Future<bool> _sendSmsSemaphore(
      String semaphoreNumber, String otp) async {
    try {
      final message =
          '$otp is your OTP from Citimovers. Valid for $_otpExpiryMinutes minutes. Do not share it.';

      // Pass body as a Map — the http package automatically encodes it as
      // application/x-www-form-urlencoded and sets the Content-Type header.
      // Do NOT set Content-Type manually; doing so alongside a Map body can
      // cause the package to skip form-encoding in http 1.x.
      final response = await http.post(
        Uri.parse(_semaphoreEndpoint),
        body: {
          'apikey': _semaphoreApiKey,
          'number': semaphoreNumber,
          'message': message,
          'sendername': _semaphoreSenderName,
        },
      );

      debugPrint('[OTP SMS] Status: ${response.statusCode}');
      debugPrint('[OTP SMS] Body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[OTP SMS] Error: $e');
      return false;
    }
  }

  /// Send OTP to phone number and store in Firestore with expiration
  static Future<bool> sendOtp(String phoneNumber) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);

      // Demo accounts: skip SMS and rate-limiting entirely
      if (_isDemoAccount(normalizedPhoneNumber)) {
        debugPrint(
            '[OTP] Demo account — skipping SMS for $normalizedPhoneNumber');
        return true;
      }

      final otp = _generateOtp();
      final semaphoreNumber = _toSemaphoreFormat(normalizedPhoneNumber);
      final firestore = FirebaseFirestore.instance;

      // Check if user is rate-limited (too many OTP requests)
      final rateLimitDoc = await firestore
          .collection('otp_rate_limits')
          .doc(normalizedPhoneNumber)
          .get();

      if (rateLimitDoc.exists) {
        final data = rateLimitDoc.data() as Map<String, dynamic>;
        final lastRequestTime = (data['lastRequestTime'] as Timestamp).toDate();
        final requestCount = data['requestCount'] as int;
        final timeSinceLastRequest = DateTime.now().difference(lastRequestTime);

        // Allow max 3 requests per 15 minutes
        if (requestCount >= _maxAttempts &&
            timeSinceLastRequest.inMinutes < 15) {
          debugPrint('OTP rate limit exceeded for $normalizedPhoneNumber');
          return false;
        }

        // Reset counter if 15 minutes have passed
        if (timeSinceLastRequest.inMinutes >= 15) {
          await firestore
              .collection('otp_rate_limits')
              .doc(normalizedPhoneNumber)
              .delete();
        }
      }

      // Send OTP via Semaphore SMS
      final smsSent = await _sendSmsSemaphore(semaphoreNumber, otp);
      if (!smsSent) {
        debugPrint('[OTP] Semaphore SMS failed for $semaphoreNumber');
        // Still store in Firestore so the user can retry on the OTP screen
        // but return false so the caller can surface an error if desired
      }

      // Store OTP in Firestore with expiration
      final otpDocRef = firestore.collection('otps').doc();
      final expiresAt =
          DateTime.now().add(Duration(minutes: _otpExpiryMinutes));

      await otpDocRef.set({
        'phoneNumber': normalizedPhoneNumber,
        'otp': otp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'attempts': 0,
        'verified': false,
      });

      // Update rate limit counter
      final rateLimitRef =
          firestore.collection('otp_rate_limits').doc(normalizedPhoneNumber);
      await rateLimitRef.set({
        'lastRequestTime': FieldValue.serverTimestamp(),
        'requestCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      debugPrint(
          '[OTP] Sent to $semaphoreNumber (stored as $normalizedPhoneNumber), expires at $expiresAt');
      return smsSent;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return false;
    }
  }

  /// Verify OTP code against stored value in Firestore
  static Future<bool> verifyOtp(String phoneNumber, String userOtp) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);

      // Demo accounts: accept the hardcoded OTP without any Firestore lookup
      if (_isDemoAccount(normalizedPhoneNumber)) {
        final valid = userOtp == _demoOtp;
        debugPrint(
            '[OTP] Demo account — verification ${valid ? 'passed' : 'failed'} for $normalizedPhoneNumber');
        return valid;
      }

      final firestore = FirebaseFirestore.instance;

      // Find the latest unverified OTP for this phone number
      final snapshot = await firestore
          .collection('otps')
          .where('phoneNumber', isEqualTo: normalizedPhoneNumber)
          .where('verified', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('No valid OTP found for $normalizedPhoneNumber');
        return false;
      }

      final otpDoc = snapshot.docs.first;
      final otpData = otpDoc.data() as Map<String, dynamic>;

      // Check if OTP has expired
      final expiresAt = (otpData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        debugPrint('OTP has expired for $normalizedPhoneNumber');
        // Mark as expired
        await otpDoc.reference.update({'verified': false, 'expired': true});
        return false;
      }

      // Check if max attempts reached
      final attempts = otpData['attempts'] as int;
      if (attempts >= _maxAttempts) {
        debugPrint('Max OTP attempts reached for $normalizedPhoneNumber');
        // Mark as blocked
        await otpDoc.reference.update({'verified': false, 'blocked': true});
        return false;
      }

      // Verify OTP
      final storedOtp = otpData['otp'] as String;
      if (storedOtp == userOtp) {
        // Mark as verified
        await otpDoc.reference.update({
          'verified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        // Clear rate limit on successful verification
        await firestore
            .collection('otp_rate_limits')
            .doc(normalizedPhoneNumber)
            .delete();

        debugPrint('OTP verified successfully for $normalizedPhoneNumber');
        return true;
      } else {
        // Increment attempt counter
        await otpDoc.reference.update({
          'attempts': FieldValue.increment(1),
        });

        final remainingAttempts = _maxAttempts - attempts - 1;
        debugPrint(
            'Invalid OTP for $normalizedPhoneNumber. Remaining attempts: $remainingAttempts');
        return false;
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }

  /// Clean up expired OTPs (should be called periodically or via Cloud Functions)
  static Future<void> cleanupExpiredOtps() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = Timestamp.now();

      final snapshot = await firestore
          .collection('otps')
          .where('expiresAt', isLessThan: now)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Cleaned up ${snapshot.docs.length} expired OTPs');
    } catch (e) {
      debugPrint('Error cleaning up expired OTPs: $e');
    }
  }
}
