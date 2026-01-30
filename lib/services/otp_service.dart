import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/keys.dart';

class OtpService {
  static const int _otpExpiryMinutes = 5; // OTP expires after 5 minutes
  static const int _maxAttempts = 3; // Maximum failed attempts before blocking

  /// Generate a 6-digit OTP (fixed to 123456 for testing/dev mode)
  static String _generateOtp() {
    // Fixed OTP for development/testing - no SMS required
    return '123456';

    // Uncomment this for production to use random OTPs:
    // final random = Random();
    // return (100000 + random.nextInt(900000)).toString();
  }

  /// Normalize phone number to +63 format
  static String _normalizePhoneNumber(String phoneNumber) {
    String normalizedPhoneNumber = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');

    if (!normalizedPhoneNumber.startsWith('+')) {
      if (normalizedPhoneNumber.startsWith('0')) {
        normalizedPhoneNumber = normalizedPhoneNumber.substring(1);
      }
      normalizedPhoneNumber = '+63$normalizedPhoneNumber';
    }

    return normalizedPhoneNumber;
  }

  /// Send OTP to phone number and store in Firestore with expiration
  /// NOTE: txtbox SMS integration disabled - OTP is now generated locally for testing
  static Future<bool> sendOtp(String phoneNumber) async {
    try {
      final otp = _generateOtp();
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
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

      // Send OTP via SMS - DISABLED FOR TESTING
      // const String url = 'https://ws-v2.txtbox.com/messaging/v1/sms/push';
      // final response = await http.post(
      //   Uri.parse(url),
      //   headers: {
      //     'X-TXTBOX-Auth': ApiKeys.txtBoxApiKey,
      //   },
      //   body: {
      //     'message':
      //           '$otp is your OTP from CitiMovers. Valid for 5 minutes. Do not share it.',
      //     'number': normalizedPhoneNumber,
      //   },
      // );

      // if (response.statusCode >= 200 && response.statusCode < 300) {
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
          'OTP generated for $normalizedPhoneNumber (not sent via SMS): $otp, expires at $expiresAt');
      return true;
      // }

      // debugPrint('Failed to send OTP: ${response.statusCode}');
      // return false;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return false;
    }
  }

  /// Verify OTP code against stored value in Firestore
  static Future<bool> verifyOtp(String phoneNumber, String userOtp) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
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
