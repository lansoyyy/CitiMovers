import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/integrations_config.dart';

class EmailJsAttachment {
  final String fileName;
  final String content; // Base64 encoded content
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

  /// Fetch image from URL and convert to base64 for attachment
  Future<EmailJsAttachment?> fetchImageAsAttachment(
      String imageUrl, String fileName) async {
    try {
      if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
        return null;
      }

      debugPrint('Fetching image for attachment: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode != 200) {
        debugPrint('Failed to fetch image: ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      final base64Content = base64Encode(bytes);

      // Determine content type from URL or default to jpeg
      String contentType = 'image/jpeg';
      if (imageUrl.toLowerCase().contains('.png')) {
        contentType = 'image/png';
      } else if (imageUrl.toLowerCase().contains('.gif')) {
        contentType = 'image/gif';
      } else if (imageUrl.toLowerCase().contains('.webp')) {
        contentType = 'image/webp';
      }

      return EmailJsAttachment(
        fileName: fileName,
        content: base64Content,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint('Error fetching image for attachment: $e');
      return null;
    }
  }

  /// Fetch multiple images and return as attachment map for EmailJS
  Future<Map<String, dynamic>> fetchImagesAsAttachments(
      Map<String, String> imageUrls) async {
    final attachments = <String, dynamic>{};

    int index = 1;
    for (final entry in imageUrls.entries) {
      if (entry.value.isEmpty) continue;

      final attachment = await fetchImageAsAttachment(
        entry.value,
        '${entry.key.replaceAll(' ', '_')}.jpg',
      );

      if (attachment != null) {
        // EmailJS uses attachment_1, attachment_2, etc. for attachment parameters
        attachments['attachment_${index}_filename'] = attachment.fileName;
        attachments['attachment_${index}_content'] = attachment.content;
        attachments['attachment_${index}_content_type'] =
            attachment.contentType ?? 'image/jpeg';
        index++;
      }
    }

    return attachments;
  }

  Future<bool> sendTemplateEmail({
    required String toEmail,
    required String subject,
    required Map<String, dynamic> templateParams,
    List<EmailJsAttachment>? attachments,
  }) async {
    try {
      final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

      // Extract subject and to_email from templateParams if present
      // This allows the EmailJS template to use its own subject formatting
      final effectiveSubject = templateParams['subject'] as String? ?? subject;
      final effectiveToEmail = templateParams['to_email'] as String? ?? toEmail;

      // Build template params with attachments
      final allTemplateParams = <String, dynamic>{
        ...templateParams,
        'to_email': effectiveToEmail,
        'subject': effectiveSubject,
      };

      // Add attachments to template params
      if (attachments != null && attachments.isNotEmpty) {
        for (int i = 0; i < attachments.length; i++) {
          final attachment = attachments[i];
          allTemplateParams['attachment_${i + 1}_filename'] =
              attachment.fileName;
          allTemplateParams['attachment_${i + 1}_content'] = attachment.content;
          if (attachment.contentType != null) {
            allTemplateParams['attachment_${i + 1}_content_type'] =
                attachment.contentType;
          }
        }
      }

      // For non-browser apps (Flutter), use Private Access Token
      // This requires the accessToken to be set in IntegrationsConfig
      final data = <String, dynamic>{
        'service_id': IntegrationsConfig.emailJsServiceId,
        'template_id': IntegrationsConfig.emailJsTemplateId,
        'user_id': IntegrationsConfig.emailJsPublicKey,
        'accessToken': IntegrationsConfig.emailJsAccessToken,
        'template_params': allTemplateParams,
      };

      debugPrint('Sending email to: $effectiveToEmail');
      debugPrint('EmailJS Service ID: ${IntegrationsConfig.emailJsServiceId}');
      debugPrint(
          'EmailJS Template ID: ${IntegrationsConfig.emailJsTemplateId}');
      debugPrint('Email Subject: $effectiveSubject');
      debugPrint('Attachments count: ${attachments?.length ?? 0}');

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
