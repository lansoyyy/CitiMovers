import 'dart:math';

import 'package:http/http.dart' as http;

import '../utils/keys.dart';

class OtpService {
  static String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

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

  static Future<bool> sendOtp(String phoneNumber) async {
    try {
      final otp = _generateOtp();
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);

      const String url = 'https://ws-v2.txtbox.com/messaging/v1/sms/push';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'X-TXTBOX-Auth': ApiKeys.txtBoxApiKey,
        },
        body: {
          'message': '$otp is your OTP. Do not share it.',
          'number': normalizedPhoneNumber,
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _tempOtpStorage[normalizedPhoneNumber] = otp;
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifyOtp(String phoneNumber, String userOtp) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      final storedOtp = _tempOtpStorage[normalizedPhoneNumber];

      if (storedOtp != null && storedOtp == userOtp) {
        _tempOtpStorage.remove(normalizedPhoneNumber);
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static final Map<String, String> _tempOtpStorage = {};
}
