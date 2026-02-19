import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/integrations_config.dart';

class EmailJsAttachment {
  final String fileName;
  final String content;
  final String? contentType;

  const EmailJsAttachment({
    required this.fileName,
    required this.content,
    this.contentType,
  });

  Map<String, dynamic> toTemplateParams(String paramPrefix) {
    return {
      '${paramPrefix}_filename': fileName,
      '${paramPrefix}_content': content,
      if (contentType != null) '${paramPrefix}_content_type': contentType,
    };
  }
}

class EmailJsService {
  static final EmailJsService instance = EmailJsService._internal();

  EmailJsService._internal();

  Future<bool> sendTemplateEmail({
    required String toEmail,
    required String subject,
    required Map<String, dynamic> templateParams,
  }) async {
    try {
      final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

      // Extract subject and to_email from templateParams if present
      // This allows the EmailJS template to use its own subject formatting
      final effectiveSubject = templateParams['subject'] as String? ?? subject;
      final effectiveToEmail = templateParams['to_email'] as String? ?? toEmail;

      // For non-browser apps (Flutter), use Private Access Token
      // This requires the accessToken to be set in IntegrationsConfig
      final data = <String, dynamic>{
        'service_id': IntegrationsConfig.emailJsServiceId,
        'template_id': IntegrationsConfig.emailJsTemplateId,
        'user_id': IntegrationsConfig.emailJsPublicKey,
        'accessToken': IntegrationsConfig.emailJsAccessToken,
        'template_params': <String, dynamic>{
          ...templateParams,
          'to_email': effectiveToEmail,
          'subject': effectiveSubject,
        },
      };

      debugPrint('Sending email to: $effectiveToEmail');
      debugPrint('EmailJS Service ID: ${IntegrationsConfig.emailJsServiceId}');
      debugPrint(
          'EmailJS Template ID: ${IntegrationsConfig.emailJsTemplateId}');
      debugPrint('Email Subject: $effectiveSubject');

      final response = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost', // Required for non-browser apps
        },
        body: jsonEncode(data),
      );

      debugPrint('EmailJS Response Status: ${response.statusCode}');
      debugPrint('EmailJS Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Email sent successfully to $effectiveToEmail');
        return true;
      } else {
        debugPrint('EmailJS Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('EmailJS Exception: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }
}
